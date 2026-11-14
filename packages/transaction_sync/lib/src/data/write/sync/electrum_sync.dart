import '../../lease_diagnostics.dart';
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import '../../writer_diagnostics.dart';

import 'package:bull_logger/bull_logger.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bull_sdk/bull_sdk.dart' show BullSdk;
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../native_write_session.dart';
import '../../datasources/revision_store_datasource.dart';
import '../../native_store_paths.dart';
import '../../sqlite_wallet_revision_reader.dart';
import '../writer_session.dart';
import '../writer_sync_operation.dart';
import '../../../domain/native_network_policy.dart';
import '../../../domain/sync_completion.dart';
import '../../../domain/sync_reason.dart';
import '../../../domain/wallet_revision.dart';
import '../../../domain/transaction_sync_failure.dart';
import '../../../domain/public_wallet_descriptor.dart';
import '../../../domain/ports/wallet_connection_port.dart';
import '../../../domain/wallet_key.dart';
import '../datasources/electrum_cache_datasource.dart';
import 'payment_observation.dart';

/// One Electrum operation inside the writer lease. Headless callers cannot provision or reconcile.
final class ElectrumSync {
  final WalletConnectionPort _connections;
  final Future<Result<WalletRevisionState, TransactionSyncFailure>> Function(
    WalletKey,
  )
  _readRevision;
  final Future<Result<void, TransactionSyncFailure>> Function(SyncCompletion)?
  _onCompletion;
  final Future<String> Function() _documentsDirectory;
  final _active =
      <WalletKey, Future<Result<SyncCompletion, TransactionSyncFailure>>>{};
  final _failures = <WalletKey, String>{};
  int _runSequence = 0;
  final _started = StreamController<WalletKey>.broadcast();
  final _finished = StreamController<SyncFinished>.broadcast();

  ElectrumSync({
    required this._connections,
    required this._documentsDirectory,
    required this._readRevision,
    this._onCompletion,
  });

  Stream<WalletKey> get started => _started.stream;
  Stream<SyncFinished> get finished => _finished.stream;

  bool isSyncing({String? walletId}) => walletId == null
      ? _active.isNotEmpty
      : _active.keys.any((key) => key.id == walletId);

  @useResult
  Future<Result<SyncCompletion, TransactionSyncFailure>> execute(
    PublicWalletDescriptor descriptor, {
    bool discover = false,
    SyncReason reason = SyncReason.auto,
    bool headless = false,
    bool allowInitialScan = true,
    Future<Result<void, TransactionSyncFailure>> Function(SyncCompletion)?
    onCompletion,
  }) {
    final failure = nativeDescriptorFailure(descriptor);
    if (failure != null) return Future.value(Err(failure));
    final key = descriptor.key;
    final previous = _active[key];
    // Joined requests keep the existing pass's reason; each queued discovery owns its reason.
    if (previous != null && !discover) return previous;
    // A discovery request must not disappear behind a routine sync. Queue it after the current operation; all native access still happens in workers.
    final completer =
        Completer<Result<SyncCompletion, TransactionSyncFailure>>();
    _active[key] = completer.future;
    unawaited(() async {
      try {
        if (previous != null) await previous;
        final watch = Stopwatch()..start();
        final runId = ++_runSequence;
        final context =
            'run=$runId chain=${key.network is BitcoinNetwork ? 'bitcoin' : 'liquid'} network=${key.network.env.name} script=${descriptor.scriptType.name} headless=$headless reason=${reason.name}';
        log.fine('Electrum sync started $context discovery=$discover');
        _started.add(key);
        var connectionSummary = 'route=unselected';
        var cacheSummary = '';
        final result = await _run(
          descriptor,
          runId: runId,
          discover: discover,
          headless: headless,
          allowInitialScan: allowInitialScan,
          onCompletion: onCompletion ?? _onCompletion,
          onCache: (summary) => cacheSummary = summary,
          onConnection: (connection) {
            connectionSummary =
                'route=${descriptor is LiquidWalletDescriptor || connection.socks5?.isNotEmpty != true ? 'direct' : 'proxy'} stop_gap=${connection.stopGap}';
          },
        );
        switch (result) {
          case Ok(:final value):
            final recovered = _failures.remove(key) != null;
            log.fine(
              'Electrum sync finished $context mode=${value.mode.name} recovered=$recovered revision=${value.revision?.revision ?? 'unknown'} incoming=${value.incomingTxids?.length ?? 'unknown'} elapsed_ms=${watch.elapsedMilliseconds} $connectionSummary $cacheSummary',
            );
          case Err(:final failure):
            final previousFailure = _failures[key];
            _failures[key] = failure.logCode;
            if (previousFailure != failure.logCode) {
              final message =
                  'Electrum sync failed $context category=${failure.logCode} elapsed_ms=${watch.elapsedMilliseconds} $connectionSummary';
              if (failure is TransactionSyncStorageFailure) {
                log.severe(
                  message: message,
                  error: 'storage',
                  trace: StackTrace.empty,
                );
              } else {
                log.warning(message);
              }
            }
        }
        _finished.add(SyncFinished(key, result));
        completer.complete(result);
      } catch (error) {
        if (_failures[key] != 'storage') {
          log.severe(
            message: 'Electrum sync unexpected failure reason=${reason.name}',
            error: 'storage',
            trace: StackTrace.empty,
          );
        }
        _failures[key] = 'storage';
        const result = Err<SyncCompletion, TransactionSyncFailure>(
          TransactionSyncStorageFailure(),
        );
        _finished.add(SyncFinished(key, result));
        completer.complete(result);
      } finally {
        if (identical(_active[key], completer.future)) {
          unawaited(_active.remove(key));
        }
      }
    }());
    return completer.future;
  }

  Future<Result<SyncCompletion, TransactionSyncFailure>> _run(
    PublicWalletDescriptor descriptor, {
    required int runId,
    required bool discover,
    required bool headless,
    required bool allowInitialScan,
    required Future<Result<void, TransactionSyncFailure>> Function(
      SyncCompletion,
    )?
    onCompletion,
    required void Function(WalletConnection) onConnection,
    required void Function(String) onCache,
  }) async {
    final String root;
    try {
      root = await _documentsDirectory();
    } on Exception {
      return const Err(TransactionSyncStorageFailure());
    }
    // The caller's reader: this class never opens, let alone creates, a store.
    final state = await _readRevision(descriptor.key);
    final int generation;
    switch (state) {
      case Ok(:final value):
        generation = value.stamp.generation;
      case Err(failure: TransactionSyncNotFoundFailure()):
        generation = 0;
      case Err(:final failure):
        if (failure is TransactionSyncBusyFailure) {
          LeaseDiagnostics(
            role: LeaseRole.writer,
            intent: LeaseIntent.sync,
            scope: headless ? LeaseScope.headless : LeaseScope.foreground,
          ).busy(LeaseBusySource.revisionRead);
        }
        return Err(failure);
    }
    var retryable = false;
    var warnedLiquidProxy = false;
    final events = ReceivePort();
    final subscription = events.listen((message) {
      if (message case (WriterLogLevel level, String text)) {
        persistWriterDiagnostic(level, text);
      } else if (message is SendPort) {
        message.send(null);
      }
    });
    try {
      return await _connections.run(
        network: descriptor.key.network,
        mayRetry: (_) => retryable,
        operation: (connection) async {
          if (descriptor is LiquidWalletDescriptor &&
              connection.socks5?.isNotEmpty == true &&
              !warnedLiquidProxy) {
            warnedLiquidProxy = true;
            log.warning(
              'Liquid sync cannot honor SOCKS setting; connecting directly',
            );
          }
          onConnection(connection);
          final attempt = await compute(
            _performSync,
            _SyncParams(
              descriptor,
              root,
              connection,
              discover,
              generation,
              events.sendPort,
              headless,
              allowInitialScan,
              onCompletion != null,
              runId,
            ),
          );
          retryable = attempt.retryable;
          if (attempt.cacheDiagnostics case final summary?) onCache(summary);
          // Capture foreground visibility immediately on native completion,
          // before Tor teardown or diagnostic flushing can yield to lifecycle changes.
          if (attempt.result case Ok(:final value) when onCompletion != null) {
            if (value.incomingTxids != null) {
              return recordPaymentObservation(attempt.result, onCompletion);
            }
          }
          return attempt.result;
        },
      );
    } finally {
      await subscription.cancel();
      events.close();
      await log.flush();
    }
  }
}

final class _SyncParams {
  final PublicWalletDescriptor descriptor;
  final String root;
  final WalletConnection connection;
  final bool discover;
  final int generation;
  final SendPort diagnostics;
  final bool headless;
  final bool allowInitialScan;
  final bool observePayments;
  final int runId;

  const _SyncParams(
    this.descriptor,
    this.root,
    this.connection,
    this.discover,
    this.generation,
    this.diagnostics,
    this.headless,
    this.allowInitialScan,
    this.observePayments,
    this.runId,
  );

  void observationWarning(String message) =>
      diagnostics.send((WriterLogLevel.warning, message));
}

final class _Attempt {
  final Result<SyncCompletion, TransactionSyncFailure> result;
  final bool retryable;

  /// Cache counts for the sync log line; never part of the public completion.
  final String? cacheDiagnostics;

  const _Attempt(this.result, {required this.retryable, this.cacheDiagnostics});
}

Future<_Attempt> _performSync(_SyncParams params) async {
  final key = params.descriptor.key;
  final failure = nativeDescriptorFailure(params.descriptor);
  if (failure != null) {
    return _Attempt(
      Err<SyncCompletion, TransactionSyncFailure>(failure),
      retryable: false,
    );
  }
  // Fail fast before SDK initialization or network access. The writer rechecks
  // existence under its lease; this preliminary check never authorizes creation.
  final path = nativeWalletStoragePath(params.root, key);
  final exists = params.descriptor is LiquidWalletDescriptor
      ? Directory(path).existsSync()
      : File(path).existsSync();
  if (!exists) {
    return _Attempt(
      const Err<SyncCompletion, TransactionSyncFailure>(
        TransactionSyncNotFoundFailure(),
      ),
      retryable: false,
    );
  }
  bdk.ElectrumClient? probe;
  try {
    probe = _connect(
      params.connection,
      direct: params.descriptor is LiquidWalletDescriptor,
    );
    probe.ping();
  } on Exception {
    return _Attempt(
      const Err<SyncCompletion, TransactionSyncFailure>(
        TransactionSyncConnectionFailure(),
      ),
      retryable: true,
    );
  } finally {
    probe?.dispose();
  }
  if (params.descriptor is LiquidWalletDescriptor) await BullSdk.init();
  final RevisionStoreDatasource revisions;
  try {
    // The foreground created the store before any pass; the worker only opens it.
    revisions = RevisionStoreDatasource.openExisting(
      revisionStorePath(params.root),
    );
  } on RevisionStoreUnavailable {
    return const _Attempt(
      Err(TransactionSyncStorageFailure()),
      retryable: false,
    );
  }
  final reader = SqliteWalletRevisionReader(revisions);
  final writer = WriterSession.worker(
    documentsDirectory: params.root,
    revisions: revisions,
    reader: reader,
    sessions: SdkWriteSessions(params.root),
    descriptor: params.descriptor,
    leaseScope: params.headless ? LeaseScope.headless : LeaseScope.compute,
    diagnostics: (level, message) => params.diagnostics.send((
      level,
      message.startsWith('event=lease_')
          ? message
          : '$message run=${params.runId} headless=${params.headless}',
    )),
  );
  try {
    final current = await reader.read(params.descriptor.key);
    if (current case Ok(
      value: final state,
    ) when state.lifecycle == WalletLifecycle.deleted) {
      return _Attempt(
        const Err<SyncCompletion, TransactionSyncFailure>(
          TransactionSyncNotFoundFailure(),
        ),
        retryable: false,
      );
    }
    if (current is Err ||
        (current as Ok<WalletRevisionState, TransactionSyncFailure>)
                .value
                .initializedSchema !=
            writerSchemaVersion) {
      if (params.headless) {
        LeaseDiagnostics(
          role: LeaseRole.writer,
          intent: LeaseIntent.sync,
          scope: LeaseScope.headless,
          sink: (level, message) => params.diagnostics.send((level, message)),
        ).busy(switch (current) {
          Err(failure: TransactionSyncBusyFailure()) =>
            LeaseBusySource.revisionRead,
          _ => LeaseBusySource.schemaGate,
        });
        return _Attempt(
          const Err<SyncCompletion, TransactionSyncFailure>(
            TransactionSyncBusyFailure(),
          ),
          retryable: false,
        );
      }
      final initialized = await writer.create(
        params.descriptor.key,
        expectedGeneration: params.generation,
        existingOnly: true,
      );
      if (initialized case Err(:final failure)) {
        return _Attempt(
          Err<SyncCompletion, TransactionSyncFailure>(failure),
          retryable: false,
        );
      }
    }
    final operation = _NativeSyncOperation(params);
    final result = await writer.sync(
      params.descriptor.key,
      expectedGeneration: params.generation,
      operation: operation,
      reconcile: !params.headless,
      preflight: params.allowInitialScan
          ? null
          : () => _checkInitialScan(params),
    );
    return switch (result) {
      Err(:final failure) => _Attempt(
        Err<SyncCompletion, TransactionSyncFailure>(failure),
        retryable: false,
      ),
      Ok(:final value) => _Attempt(
        operation.result?.map(
              (completion) => completion.committed(value.revision),
            ) ??
            const Err<SyncCompletion, TransactionSyncFailure>(
              TransactionSyncStorageFailure(),
            ),
        retryable: false,
        cacheDiagnostics: operation.cacheDiagnostics,
      ),
    };
  } finally {
    await reader.close();
    revisions.close();
    // Same-port ordering plus acknowledgement drains all diagnostics before
    // compute returns and the foreground closes its listener.
    final acknowledged = ReceivePort();
    params.diagnostics.send(acknowledged.sendPort);
    await acknowledged.first;
    acknowledged.close();
  }
}

final class _NativeSyncOperation
    implements
        WriterSyncOperation,
        WriterSyncMutation,
        WriterSyncChanges,
        WriterSyncSpendObservation {
  Map<String, Set<String>> _trackedSpends = {};
  @override
  Set<String> observedSpendTransactions = {};
  @override
  Map<String, Set<String>> spendTransactionInputs = {};
  @override
  Set<String> settledSpendTransactions = {};
  @override
  void trackSpendTransactions(Map<String, Set<String>> inputsByTxid) =>
      _trackedSpends = inputsByTxid;
  @override
  bool mayHaveMutated = false;
  @override
  bool hasChanges = true;
  final _SyncParams params;
  Result<SyncCompletion, TransactionSyncFailure>? result;
  String? cacheDiagnostics;
  _NativeSyncOperation(this.params);
  @override
  Future<Result<void, TransactionSyncFailure>> execute(
    PublicWalletDescriptor descriptor, {
    required int? issuedReceiveIndex,
  }) async {
    final attempt = await _performNativeSync(
      params,
      issuedReceiveIndex,
      () => mayHaveMutated = true,
      (changed) => hasChanges = changed,
      _trackedSpends,
      (evidence) {
        observedSpendTransactions = evidence.observed;
        spendTransactionInputs = evidence.inputs;
        settledSpendTransactions = evidence.settled;
      },
    );
    result = attempt.result;
    cacheDiagnostics = attempt.cacheDiagnostics;
    return switch (attempt.result) {
      Ok() => const Ok(null),
      Err(:final failure) => Err(failure),
    };
  }
}

Future<_Attempt> _performNativeSync(
  _SyncParams params,
  int? issuedReceiveIndex,
  void Function() markMutation,
  void Function(bool) reportChanges,
  Map<String, Set<String>> trackedSpends,
  void Function(_SpendEvidence) reportSpendEvidence,
) async {
  final watch = Stopwatch()..start();
  final descriptor = params.descriptor;
  final connection = params.connection;
  final path = nativeWalletStoragePath(params.root, descriptor.key);
  if (descriptor is LiquidWalletDescriptor) {
    if (!Directory(path).existsSync()) {
      return _Attempt(
        const Err<SyncCompletion, TransactionSyncFailure>(
          TransactionSyncNotFoundFailure(),
        ),
        retryable: false,
      );
    }
    final network = switch (descriptor.key.network) {
      LiquidNetwork.mainnet => lwk.LiquidNetwork.mainnet,
      LiquidNetwork.testnet => lwk.LiquidNetwork.testnet,
      LiquidNetwork.regtest => lwk.LiquidNetwork.regtest,
      _ => null,
    };
    if (network == null) {
      return _Attempt(
        const Err<SyncCompletion, TransactionSyncFailure>(
          TransactionSyncUnsupportedNetworkFailure(),
        ),
        retryable: false,
      );
    }
    lwk.Wallet? wallet;
    TransactionSyncFailure failure = const TransactionSyncStorageFailure();
    try {
      // LWK init may mutate its cache. Never fallback once it has been called.
      markMutation();
      wallet = await lwk.Wallet.init(
        network: network,
        dbpath: path,
        descriptor: lwk.Descriptor(
          ctDescriptor: descriptor.combinedCtDescriptor,
        ),
      );
      failure = const TransactionSyncConnectionFailure();
      await wallet.sync_(
        electrumUrl: connection.url,
        validateDomain: connection.validateDomain,
        timeout: connection.timeout.inSeconds,
        stopAtIndex: issuedReceiveIndex,
      );
      final syncedWallet = wallet;
      final incoming = params.observePayments
          ? await collectPaymentObservation(
              () async => {
                for (final tx in await syncedWallet.txs())
                  if (tx.kind == 'incoming') tx.txid,
              },
              warning: params.observationWarning,
            )
          : null;
      return _Attempt(
        Ok<SyncCompletion, TransactionSyncFailure>(
          SyncCompletion(
            SyncMode.liquid,
            watch.elapsed,
            incomingTxids: incoming,
          ),
        ),
        retryable: false,
      );
    } on lwk.LwkError catch (error) {
      return _Attempt(
        Err<SyncCompletion, TransactionSyncFailure>(
          error.msg.contains('UpdateOnDifferentStatus')
              ? const TransactionSyncNeedsRepairFailure()
              : failure,
        ),
        retryable: false,
      );
    } on Exception {
      return _Attempt(
        Err<SyncCompletion, TransactionSyncFailure>(failure),
        retryable: false,
      );
    } finally {
      wallet?.dispose();
    }
  }
  if (descriptor is! BitcoinWalletDescriptor) {
    return _Attempt(
      const Err<SyncCompletion, TransactionSyncFailure>(
        TransactionSyncInvalidCatalogFailure(),
      ),
      retryable: false,
    );
  }
  final kind = switch (descriptor.key.network) {
    BitcoinNetwork.mainnet => bdk.NetworkKind.main,
    BitcoinNetwork.testnet || BitcoinNetwork.regtest => bdk.NetworkKind.test,
    _ => null,
  };
  if (kind == null) {
    return _Attempt(
      const Err<SyncCompletion, TransactionSyncFailure>(
        TransactionSyncUnsupportedNetworkFailure(),
      ),
      retryable: false,
    );
  }
  if (!File(path).existsSync()) {
    return _Attempt(
      const Err<SyncCompletion, TransactionSyncFailure>(
        TransactionSyncNotFoundFailure(),
      ),
      retryable: false,
    );
  }
  bdk.ElectrumClient? client;
  bdk.Persister? persister;
  bdk.Wallet? wallet;
  bdk.Descriptor? external;
  bdk.Descriptor? internal;
  ElectrumCacheDatasource? cache;
  var retryable = true;
  TransactionSyncFailure failure = const TransactionSyncConnectionFailure();
  try {
    client = _connect(connection);
    // Even opening a persister can initialize tables. Fallback is deliberately limited to connection establishment, before any native store is opened.
    retryable = false;
    failure = const TransactionSyncStorageFailure();
    external = bdk.Descriptor(
      descriptor: descriptor.externalDescriptor,
      networkKind: kind,
    );
    internal = bdk.Descriptor(
      descriptor: descriptor.internalDescriptor,
      networkKind: kind,
    );
    persister = bdk.Persister.newSqlite(path: path);
    wallet = bdk.Wallet.load(
      descriptor: external,
      changeDescriptor: internal,
      persister: persister,
      lookahead: 25,
    );
    final expected = switch (descriptor.key.network) {
      BitcoinNetwork.mainnet => bdk.Network.bitcoin,
      BitcoinNetwork.testnet => bdk.Network.testnet,
      BitcoinNetwork.regtest => bdk.Network.regtest,
      _ => null,
    };
    if (wallet.network() != expected) {
      return _Attempt(
        const Err<SyncCompletion, TransactionSyncFailure>(
          TransactionSyncInvalidCatalogFailure(),
        ),
        retryable: false,
      );
    }
    final checkpoint = wallet.latestCheckpoint();
    final height = checkpoint.height;
    checkpoint.hash.dispose();
    final mode = params.discover
        ? SyncMode.discovery
        : height == 0
        ? SyncMode.initialScan
        : SyncMode.revealedScripts;
    cache = ElectrumCacheDatasource.open(path);
    final prefill = cache?.prefill(client, wallet);
    final batchSize = (connection.stopGap ~/ 4).clamp(50, 1000);
    // Every pass covers the revealed scripts: the pinned bdk_chain full scan
    // counts the stop gap from index 0 and can miss a revealed script beyond
    // last-used + stop gap. Scan passes then add the unrevealed gap window.
    failure = const TransactionSyncStorageFailure();
    final before = wallet.staged();
    final cleanStage = before == null;
    before?.dispose();
    failure = const TransactionSyncConnectionFailure();
    final revealed = _syncRevealedScripts(client, wallet, batchSize);
    failure = const TransactionSyncStorageFailure();
    try {
      markMutation();
      wallet.applyUpdate(update: revealed);
    } finally {
      revealed.dispose();
    }
    if (mode != SyncMode.revealedScripts) {
      failure = const TransactionSyncConnectionFailure();
      final scanned = _fullScan(
        client,
        wallet,
        stopGap: connection.stopGap,
        batchSize: batchSize,
      );
      failure = const TransactionSyncStorageFailure();
      try {
        wallet.applyUpdate(update: scanned);
      } finally {
        scanned.dispose();
      }
    }
    // Spend evidence reads this pass's staged deltas from both updates and the
    // final canonical state, and is reported only once the pass persisted.
    final evidence = cleanStage ? _spendEvidence(wallet, trackedSpends) : null;
    reportChanges(wallet.persist(persister: persister));
    if (evidence != null) reportSpendEvidence(evidence);
    final parents = cache?.rememberParents(client, wallet);
    final syncedWallet = wallet;
    final incoming = params.observePayments
        ? await collectPaymentObservation(
            () => _bitcoinIncoming(syncedWallet),
            warning: params.observationWarning,
          )
        : null;
    return _Attempt(
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
    return _Attempt(
      Err<SyncCompletion, TransactionSyncFailure>(failure),
      retryable: retryable,
    );
  } finally {
    cache?.close();
    wallet?.dispose();
    persister?.dispose();
    internal?.dispose();
    external?.dispose();
    client?.dispose();
  }
}

bdk.Update _syncRevealedScripts(
  bdk.ElectrumClient client,
  bdk.Wallet wallet,
  int batchSize,
) {
  final builder = wallet.startSyncWithRevealedSpks();
  bdk.SyncRequest? request;
  try {
    request = builder.build();
    return client.sync_(
      request: request,
      batchSize: batchSize,
      fetchPrevTxouts: true,
    );
  } finally {
    request?.dispose();
    builder.dispose();
  }
}

bdk.Update _fullScan(
  bdk.ElectrumClient client,
  bdk.Wallet wallet, {
  required int stopGap,
  required int batchSize,
}) {
  final builder = wallet.startFullScan();
  bdk.FullScanRequest? request;
  try {
    request = builder.build();
    return client.fullScan(
      request: request,
      stopGap: stopGap,
      batchSize: batchSize,
      fetchPrevTxouts: true,
    );
  } finally {
    request?.dispose();
    builder.dispose();
  }
}

bdk.ElectrumClient _connect(
  WalletConnection connection, {
  bool direct = false,
}) {
  bdk.ElectrumClient build() => bdk.ElectrumClient(
    url: electrumClientUrl(connection.url),
    socks5: !direct && connection.socks5?.isNotEmpty == true
        ? connection.socks5
        : null,
    timeout: connection.timeout.inSeconds.clamp(0, 255),
    retry: connection.retry.clamp(0, 255),
    validateDomain: connection.validateDomain,
  );
  try {
    return build();
  } on bdk.CouldNotCreateConnectionElectrumException catch (error) {
    if (error.errorMessage.contains('Failed to install CryptoProvider')) {
      return build();
    }
    rethrow;
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

// Runs under the writer lock, BEFORE recording an intent. A deferred initial
// scan must leave no pending write and must never initialize an absent store.
Future<Result<void, TransactionSyncFailure>> _checkInitialScan(
  _SyncParams params,
) async {
  final descriptor = params.descriptor;
  if (descriptor is! BitcoinWalletDescriptor) return const Ok(null);
  final path = nativeWalletStoragePath(params.root, descriptor.key);
  if (!File(path).existsSync()) {
    return const Err(TransactionSyncNotFoundFailure());
  }
  final kind = descriptor.key.network == BitcoinNetwork.mainnet
      ? bdk.NetworkKind.main
      : bdk.NetworkKind.test;
  final external = bdk.Descriptor(
    descriptor: descriptor.externalDescriptor,
    networkKind: kind,
  );
  final internal = bdk.Descriptor(
    descriptor: descriptor.internalDescriptor,
    networkKind: kind,
  );
  bdk.Persister? persister;
  bdk.Wallet? wallet;
  try {
    persister = bdk.Persister.newSqlite(path: path);
    wallet = bdk.Wallet.load(
      descriptor: external,
      changeDescriptor: internal,
      persister: persister,
      lookahead: 25,
    );
    final expected = switch (descriptor.key.network) {
      BitcoinNetwork.mainnet => bdk.Network.bitcoin,
      BitcoinNetwork.testnet => bdk.Network.testnet,
      BitcoinNetwork.regtest => bdk.Network.regtest,
      _ => null,
    };
    if (wallet.network() != expected) {
      return const Err(TransactionSyncInvalidCatalogFailure());
    }
    final checkpoint = wallet.latestCheckpoint();
    try {
      return checkpoint.height == 0
          ? const Err(TransactionSyncInitialScanRequiredFailure())
          : const Ok(null);
    } finally {
      checkpoint.hash.dispose();
    }
  } on Exception {
    return const Err(TransactionSyncStorageFailure());
  } finally {
    wallet?.dispose();
    persister?.dispose();
    internal.dispose();
    external.dispose();
  }
}

/// BDK requires an explicit transport; Liquid catalog URLs use LWK's host:port.
@visibleForTesting
String electrumClientUrl(String url) =>
    url.contains('://') ? url : 'ssl://$url';

typedef _SpendEvidence = ({
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
/// is confirmed, or is itself a tracked spend observed in this pass. An
/// eviction is one endpoint's omission: like any absence, it settles nothing.
_SpendEvidence _spendEvidence(
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
      // Outpoints spent by a confirmed transaction, or by a tracked
      // replacement this pass observed.
      final spent = <String>{};
      for (final tx in wallet.transactions()) {
        final id = tx.transaction.computeTxid();
        final confirmed = tx.chainPosition is bdk.ConfirmedChainPosition;
        final proof = confirmed || observed.contains(id.toString());
        id.dispose();
        final outpoints = _takeInputs(tx);
        if (proof) spent.addAll(outpoints);
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
