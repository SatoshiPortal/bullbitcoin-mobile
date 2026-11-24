import 'dart:io';
import 'dart:typed_data';

import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:primitives/primitives.dart';

import '../../../domain/public_wallet_descriptor.dart';
import '../../../domain/sync_completion.dart';
import '../../../domain/sync_failure.dart';
import '../../../domain/sync_transaction_target.dart';
import '../../native_store_paths.dart';
import '../datasources/bdk_electrum_datasource.dart';
import '../datasources/bdk_wallet_store_datasource.dart';
import '../datasources/electrum_cache_datasource.dart';
import '../datasources/native_store_errors.dart';
import 'payment_observation.dart';
import 'sync_pass.dart';

/// One Bitcoin pass: choose the mode, prefill the client from the cache,
/// apply the revealed-script update and, when scanning, the full scan, then
/// persist once and report spend evidence. Only connection establishment,
/// before the store is opened, may be retried on another server.
Future<SyncPassOutcome> bitcoinSyncPass(
  SyncParams params,
  BitcoinWalletDescriptor descriptor, {
  required Map<String, Set<String>> trackedSpends,
  required void Function() markMutation,
  required void Function(bool) reportChanges,
  required void Function(SpendEvidence) reportSpendEvidence,
}) async {
  final watch = Stopwatch()..start();
  final connection = params.connection;
  final targets = params.targets;
  final targeted = targets.isNotEmpty;
  final path = nativeWalletStoragePath(params.root, descriptor.key);
  if (BdkWalletStoreDatasource.network(descriptor.key.network) == null) {
    return SyncPassOutcome.failed(const SyncUnsupportedNetworkFailure());
  }
  if (!File(path).existsSync()) {
    return SyncPassOutcome.failed(SyncNotFoundFailure());
  }
  BdkElectrumDatasource? electrum;
  BdkWalletStoreDatasource? store;
  ElectrumCacheDatasource? cache;
  var retryable = true;
  SyncFailure failure = const SyncConnectionFailure();
  try {
    electrum = BdkElectrumDatasource.connect(connection);
    // Even opening a persister can initialize tables. Fallback is deliberately
    // limited to connection establishment, before any native store is opened.
    retryable = false;
    failure = const SyncStorageFailure();
    try {
      store = BdkWalletStoreDatasource.load(path, descriptor);
    } on NativeNetworkUnsupported {
      return SyncPassOutcome.failed(const SyncInvalidCatalogFailure());
    }
    final wallet = store.wallet;
    final checkpoint = wallet.latestCheckpoint();
    final height = checkpoint.height;
    checkpoint.hash.dispose();
    final mode = targeted
        ? SyncMode.targeted
        : params.discover
        ? SyncMode.discovery
        : height == 0
        ? SyncMode.initialScan
        : SyncMode.revealedScripts;
    cache = ElectrumCacheDatasource.open(path);
    final prefill = cache == null
        ? null
        : prefillFromCache(cache, electrum, wallet);
    final batchSize = (connection.stopGap ~/ 4).clamp(50, 1000);
    // Every non-targeted pass covers the revealed scripts: the pinned
    // bdk_chain full scan counts the stop gap from index 0 and can miss a
    // revealed script beyond last-used + stop gap. Scan passes then add the
    // unrevealed gap window.
    final before = wallet.staged();
    final cleanStage = before == null;
    before?.dispose();
    if (targeted) {
      // A targeted pass covers the wallet's own indices only, and judges its
      // targets from the canonical transactions it applies, never from the id
      // it was given. Coverage is per target: a proposal a receiver must judge
      // carries counterparty outputs and sender inputs this wallet owns no
      // script of, so one owned component is enough to cover the target.
      final coverage = _coveredIndices(wallet, targets);
      if (coverage.targets.isEmpty) {
        // No target touches a script or outpoint this wallet owns: nothing was
        // covered, so nothing may be reported absent.
        reportChanges(false);
        return SyncPassOutcome(
          Ok(SyncCompletion(mode, watch.elapsed)),
          retryable: false,
          cacheDiagnostics: ElectrumCacheDatasource.describe(
            opened: cache != null,
            rebuilt: cache?.rebuilt ?? false,
            prefill: prefill,
            parents: null,
          ),
        );
      }
      failure = const SyncConnectionFailure();
      final bdk.Update update;
      try {
        update = electrum.syncScriptIndices(
          wallet,
          externalIndices: coverage.indices.external,
          internalIndices: coverage.indices.internal,
          batchSize: batchSize,
        );
      } on bdk.SpkIndexException {
        failure = const SyncStorageFailure();
        rethrow;
      }
      failure = const SyncStorageFailure();
      final bdk.UpdateTransactionObservations observations;
      try {
        observations = update.transactionObservations();
        markMutation();
        wallet.applyUpdate(update: update);
      } finally {
        update.dispose();
      }
      final presence = _targetPresence(wallet, coverage.targets, observations);
      reportChanges(store.persist());
      final evidence = cleanStage
          ? _spendEvidence(wallet, trackedSpends)
          : null;
      if (evidence != null) reportSpendEvidence(evidence);
      return SyncPassOutcome(
        Ok(
          SyncCompletion(
            mode,
            watch.elapsed,
            visibleTransactionIds: presence.visible,
            coveredTransactionIds: presence.conclusive,
          ),
        ),
        retryable: false,
        cacheDiagnostics: ElectrumCacheDatasource.describe(
          opened: cache != null,
          rebuilt: cache?.rebuilt ?? false,
          prefill: prefill,
          parents: null,
        ),
      );
    }
    failure = const SyncConnectionFailure();
    final revealed = electrum.syncRevealedScripts(wallet, batchSize: batchSize);
    failure = const SyncStorageFailure();
    try {
      markMutation();
      wallet.applyUpdate(update: revealed);
    } finally {
      revealed.dispose();
    }
    if (mode != SyncMode.revealedScripts) {
      failure = const SyncConnectionFailure();
      final scanned = electrum.fullScan(
        wallet,
        stopGap: connection.stopGap,
        batchSize: batchSize,
      );
      failure = const SyncStorageFailure();
      try {
        wallet.applyUpdate(update: scanned);
      } finally {
        scanned.dispose();
      }
    }
    // Spend evidence reads this pass's staged deltas from both updates and the
    // final canonical state, and is reported only once the pass persisted.
    final evidence = cleanStage ? _spendEvidence(wallet, trackedSpends) : null;
    reportChanges(store.persist());
    if (evidence != null) reportSpendEvidence(evidence);
    final parents = cache == null
        ? null
        : rememberParents(cache, electrum, wallet);
    final incoming = params.collectIncoming
        ? await collectPaymentObservation(
            () => _bitcoinIncoming(wallet),
            warning: params.observationWarning,
          )
        : null;
    return SyncPassOutcome(
      Ok(SyncCompletion(mode, watch.elapsed, incomingTxids: incoming)),
      retryable: false,
      cacheDiagnostics: ElectrumCacheDatasource.describe(
        opened: cache != null,
        rebuilt: cache?.rebuilt ?? false,
        prefill: prefill,
        parents: parents,
      ),
    );
  } on Exception {
    return SyncPassOutcome(Err(failure), retryable: retryable);
  } finally {
    cache?.close();
    store?.close();
    electrum?.dispose();
  }
}

/// Runs under the writer lock, BEFORE recording an intent. A deferred initial
/// scan must leave no pending write and must never initialize an absent store.
Future<Result<void, SyncFailure>> checkInitialScan(SyncParams params) async {
  final descriptor = params.descriptor;
  if (descriptor is! BitcoinWalletDescriptor) return const Ok(null);
  final path = nativeWalletStoragePath(params.root, descriptor.key);
  BdkWalletStoreDatasource? store;
  try {
    store = BdkWalletStoreDatasource.load(path, descriptor);
    final checkpoint = store.wallet.latestCheckpoint();
    try {
      return checkpoint.height == 0
          ? const Err(SyncInitialScanRequiredFailure())
          : const Ok(null);
    } finally {
      checkpoint.hash.dispose();
    }
  } on NativeStoreMissing {
    return const Err(SyncNotFoundFailure());
  } on NativeNetworkUnsupported {
    return const Err(SyncInvalidCatalogFailure());
  } on Exception {
    return const Err(SyncStorageFailure());
  } finally {
    store?.close();
  }
}

/// Seeds the client before a scan with the wallet's transactions, its direct
/// confirmation anchors and the stored parents whose bytes still hash to
/// their txid; the others are dropped. A transitive anchor carries a
/// descendant's block, not the transaction's, so it is never passed.
/// The server still answers every script history and header request, so
/// discovery and reorg handling are unchanged.
ElectrumCachePrefill prefillFromCache(
  ElectrumCacheDatasource cache,
  BdkElectrumDatasource electrum,
  bdk.Wallet wallet,
) {
  final parents = <bdk.Transaction>[];
  var canonical = <bdk.CanonicalTx>[];
  final anchors = <bdk.TxAnchor>[];
  var transactions = 0;
  var anchorCount = 0;
  var dropped = 0;
  try {
    final corrupt = <String>[];
    for (final (txid, raw) in cache.storedParents()) {
      bdk.Transaction? tx;
      try {
        tx = bdk.Transaction(transactionBytes: raw);
        if (_txid(tx) == txid) {
          parents.add(tx);
          tx = null;
          continue;
        }
      } catch (_) {
        // Unparsable bytes are dropped below.
      } finally {
        tx?.dispose();
      }
      corrupt.add(txid);
    }
    cache.dropParents(corrupt);
    dropped = corrupt.length;
    canonical = wallet.transactions();
    transactions = canonical.length;
    electrum.populateTxCache([
      for (final tx in canonical) tx.transaction,
      ...parents,
    ]);
    for (final tx in canonical) {
      if (tx.chainPosition case bdk.ConfirmedChainPosition(
        transitively: null,
        :final confirmationBlockTime,
      )) {
        anchors.add(
          bdk.TxAnchor(
            txid: tx.transaction.computeTxid(),
            anchor: confirmationBlockTime,
          ),
        );
      }
    }
    anchorCount = anchors.length;
    electrum.populateAnchorCache(anchors);
    return (
      transactions: transactions,
      parents: parents.length,
      anchors: anchorCount,
      droppedParents: dropped,
      failed: false,
    );
  } catch (_) {
    // A client without a prefill still syncs, it only downloads more.
    return (
      transactions: transactions,
      parents: parents.length,
      anchors: anchorCount,
      droppedParents: dropped,
      failed: true,
    );
  } finally {
    for (final anchor in anchors) {
      anchor.txid.dispose();
    }
    _disposeCanonical(canonical);
    for (final parent in parents) {
      parent.dispose();
    }
  }
}

/// Stores the parents of the wallet's transactions after a scan, all or
/// none. [electrum] must be the client that scanned with previous outputs:
/// it answers from its cache.
ElectrumCacheParents rememberParents(
  ElectrumCacheDatasource cache,
  BdkElectrumDatasource electrum,
  bdk.Wallet wallet,
) {
  var canonicalTransactions = <bdk.CanonicalTx>[];
  try {
    final own = <String>{};
    final spent = <String>{};
    canonicalTransactions = wallet.transactions();
    for (final canonical in canonicalTransactions) {
      final tx = canonical.transaction;
      own.add(_txid(tx));
      if (tx.isCoinbase()) continue;
      for (final input in tx.input()) {
        try {
          spent.add(input.previousOutput.txid.toString());
        } finally {
          input.previousOutput.txid.dispose();
          input.scriptSig.dispose();
        }
      }
    }
    final missing = spent.difference(own).difference(cache.knownParents());
    if (missing.isEmpty) return (stored: 0, failed: false);
    final fetched = <String, Uint8List>{};
    for (final txid in missing) {
      final id = bdk.Txid.fromString(hex: txid);
      final bdk.Transaction tx;
      try {
        tx = electrum.fetchTx(id);
      } finally {
        id.dispose();
      }
      try {
        if (_txid(tx) == txid) fetched[txid] = tx.serialize();
      } finally {
        tx.dispose();
      }
    }
    cache.storeParents(fetched);
    return (stored: fetched.length, failed: false);
  } catch (_) {
    // The next scan downloads the parents again and retries.
    return (stored: 0, failed: true);
  } finally {
    _disposeCanonical(canonicalTransactions);
  }
}

Set<String> _bitcoinIncoming(bdk.Wallet wallet) {
  final incoming = <String>{};
  for (final tx in wallet.transactions()) {
    try {
      final amounts = wallet.sentAndReceived(tx: tx.transaction);
      try {
        if (amounts.received.toSat() > amounts.sent.toSat()) {
          final id = tx.transaction.computeTxid();
          try {
            incoming.add(id.toString());
          } finally {
            id.dispose();
          }
        }
      } finally {
        amounts.received.dispose();
        amounts.sent.dispose();
      }
    } finally {
      tx.transaction.dispose();
      if (tx.chainPosition case bdk.ConfirmedChainPosition(
        :final confirmationBlockTime,
        :final transitively,
      )) {
        confirmationBlockTime.blockId.hash.dispose();
        transitively?.dispose();
      }
    }
  }
  return incoming;
}

typedef SpendEvidence = ({
  Set<String> observed,
  Map<String, Set<String>> inputs,
  Set<String> settled,
});

String _outpoint(bdk.OutPoint outpoint) => '${outpoint.txid}:${outpoint.vout}';

/// Returns the outpoints [tx] spends and frees its native handles.
Set<String> _takeInputs(bdk.CanonicalTx tx) {
  final inputs = <String>{};
  for (final input in tx.transaction.input()) {
    inputs.add(_outpoint(input.previousOutput));
    input.previousOutput.txid.dispose();
    input.scriptSig.dispose();
  }
  tx.transaction.dispose();
  if (tx.chainPosition case bdk.ConfirmedChainPosition(
    :final confirmationBlockTime,
    :final transitively,
  )) {
    confirmationBlockTime.blockId.hash.dispose();
    transitively?.dispose();
  }
  return inputs;
}

/// No local insertion is performed. Only advancing server deltas can prove
/// unconfirmed visibility; canonical confirmation is separate chain evidence.
/// A tracked spend that left the canonical set is settled, for this pass
/// only, when a canonical transaction spends one of its recorded inputs and
/// is confirmed. An unconfirmed replacement, tracked or foreign, and an
/// eviction are insufficient: like any absence, they settle nothing.
SpendEvidence _spendEvidence(
  bdk.Wallet wallet,
  Map<String, Set<String>> tracked,
) {
  final observed = <String>{};
  final inputs = <String, Set<String>>{};
  final settled = <String>{};
  if (tracked.isEmpty) {
    return (observed: observed, inputs: inputs, settled: settled);
  }
  final staged = wallet.staged();
  final positive = <String>{};
  try {
    final graph = staged?.txGraphChangeset();
    if (graph != null) {
      positive.addAll(graph.lastSeen.keys.map((id) => id.toString()));
      positive.addAll(graph.anchors.map((anchor) => anchor.txid.toString()));
      for (final tx in graph.txs) {
        tx.dispose();
      }
      for (final entry in graph.txouts.entries) {
        entry.key.dispose();
        entry.value.scriptPubkey.dispose();
        entry.value.value.dispose();
      }
      for (final id in {
        ...graph.lastSeen.keys,
        ...graph.firstSeen.keys,
        ...graph.lastEvicted.keys,
      }) {
        id.dispose();
      }
      for (final anchor in graph.anchors) {
        anchor.txid.dispose();
        anchor.confirmationBlockTime.blockId.hash.dispose();
      }
    }
    final displaced = <String>{};
    for (final id in tracked.keys) {
      final txid = bdk.Txid.fromString(hex: id);
      try {
        final tx = wallet.getTx(txid: txid);
        if (tx == null) {
          if (tracked[id]?.isNotEmpty ?? false) displaced.add(id);
          continue;
        }
        if (positive.contains(id) ||
            tx.chainPosition is bdk.ConfirmedChainPosition) {
          observed.add(id);
        }
        final spent = _takeInputs(tx);
        if (tracked[id]?.isEmpty ?? true) inputs[id] = spent;
      } finally {
        txid.dispose();
      }
    }
    if (displaced.isNotEmpty) {
      // Only positive canonical confirmation settles an absent transaction.
      final spent = <String>{};
      for (final tx in wallet.transactions()) {
        final confirmed = tx.chainPosition is bdk.ConfirmedChainPosition;
        final outpoints = _takeInputs(tx);
        if (confirmed) spent.addAll(outpoints);
      }
      settled.addAll(
        displaced.where((id) => tracked[id]?.any(spent.contains) ?? false),
      );
    }
    return (observed: observed, inputs: inputs, settled: settled);
  } finally {
    staged?.dispose();
  }
}

String _txid(bdk.Transaction tx) {
  final id = tx.computeTxid();
  try {
    return id.toString();
  } finally {
    id.dispose();
  }
}

void _disposeCanonical(List<bdk.CanonicalTx> transactions) {
  for (final tx in transactions) {
    tx.transaction.dispose();
    if (tx.chainPosition case bdk.ConfirmedChainPosition(
      :final confirmationBlockTime,
      :final transitively,
    )) {
      confirmationBlockTime.blockId.hash.dispose();
      transitively?.dispose();
    }
  }
}

typedef _SpkIndices = ({List<int> external, List<int> internal});

typedef _TargetCoverage = ({_SpkIndices indices, Set<String> targets});

/// The wallet's own derivation indices the pass must cover to judge [targets],
/// and which targets those indices actually cover.
///
/// An index comes from every output script they pay, resolved by the wallet
/// itself, and from every outpoint they spend, resolved against the outputs
/// this wallet ever held, spent included. A target is covered as soon as one
/// of its components resolves to such an index: a proposal carries
/// counterparty outputs and sender inputs this wallet owns nothing of, and
/// requiring more than one owned component would leave a legitimate Payjoin
/// uncovered.
///
/// An index that cannot be resolved is not guessed: a target this wallet owns
/// no script or outpoint of is not covered, and the caller reports no proof
/// rather than evidence.
_TargetCoverage _coveredIndices(
  bdk.Wallet wallet,
  List<SyncTransactionTarget> targets,
) {
  final external = <int>{};
  final internal = <int>{};
  final covered = <String>{};
  final lastRevealed = {
    for (final keychain in bdk.KeychainKind.values)
      keychain: wallet.derivationIndex(keychain: keychain),
  };
  bool remember(bdk.KeychainKind keychain, int index) {
    // The lookahead index can recognize a script that cannot be queried by
    // startSyncWithSpkIndices yet. Never reveal it during presence checking.
    final last = lastRevealed[keychain];
    if (last == null || index > last) return false;
    switch (keychain) {
      case bdk.KeychainKind.external_:
        external.add(index);
      case bdk.KeychainKind.internal:
        internal.add(index);
    }
    return true;
  }

  final spentByOutpoint = <String, List<String>>{};
  for (final target in targets) {
    for (final outpoint in target.spentOutpoints) {
      (spentByOutpoint['${outpoint.txId}:${outpoint.vout}'] ??= <String>[]).add(
        target.txid,
      );
    }
  }
  if (spentByOutpoint.isNotEmpty) {
    for (final output in wallet.listOutput()) {
      try {
        final ownedBy = spentByOutpoint[_outpoint(output.outpoint)];
        if (ownedBy != null &&
            remember(output.keychain, output.derivationIndex)) {
          covered.addAll(ownedBy);
        }
      } finally {
        output.outpoint.txid.dispose();
        output.txout.scriptPubkey.dispose();
        output.txout.value.dispose();
        if (output.chainPosition case bdk.ConfirmedChainPosition(
          :final confirmationBlockTime,
          :final transitively,
        )) {
          confirmationBlockTime.blockId.hash.dispose();
          transitively?.dispose();
        }
      }
    }
  }
  for (final target in targets) {
    for (final script in target.outputScripts) {
      final native = bdk.Script(rawOutputScript: script);
      try {
        final derived = wallet.derivationOfSpk(spk: native);
        if (derived != null && remember(derived.keychain, derived.index)) {
          covered.add(target.txid);
        }
      } finally {
        native.dispose();
      }
    }
  }
  return (
    indices: (
      external: external.toList(growable: false),
      internal: internal.toList(growable: false),
    ),
    targets: covered,
  );
}

/// Require this update as evidence even for an existing canonical transaction.
/// A listed transaction without a valid anchor or unconfirmed observation
/// never proves presence or absence, nor does a sighting BDK did not accept
/// into the canonical graph.
({Set<String> visible, Set<String> conclusive}) _targetPresence(
  bdk.Wallet wallet,
  Set<String> queried,
  bdk.UpdateTransactionObservations observations,
) {
  final observed = {...observations.unconfirmed, ...observations.anchored};
  final listed = observations.listed.toSet();
  final visible = <String>{};
  final conclusive = <String>{};
  for (final id in queried) {
    final txid = bdk.Txid.fromString(hex: id);
    try {
      final tx = wallet.getTx(txid: txid);
      final seen = observed.contains(id);
      if (tx == null) {
        if (!seen && !listed.contains(id)) conclusive.add(id);
        continue;
      }
      try {
        if (seen) {
          visible.add(id);
          conclusive.add(id);
        }
      } finally {
        tx.transaction.dispose();
        if (tx.chainPosition case bdk.ConfirmedChainPosition(
          :final confirmationBlockTime,
          :final transitively,
        )) {
          confirmationBlockTime.blockId.hash.dispose();
          transitively?.dispose();
        }
      }
    } finally {
      txid.dispose();
    }
  }
  return (visible: visible, conclusive: conclusive);
}
