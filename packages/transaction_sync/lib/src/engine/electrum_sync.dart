import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import '../write/writer_diagnostics.dart';

import 'package:bull_logger/bull_logger.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bull_sdk/bull_sdk.dart' show BullSdk;
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../../write.dart';
import '../domain/wallet_revision.dart';
import '../domain/reserved_address_port.dart';
import '../domain/transaction_sync_failure.dart';
import '../domain/wallet_catalog_port.dart';
import '../domain/wallet_connection_policy.dart';
import '../domain/wallet_key.dart';
import 'bdk_electrum_cache.dart';
import 'payment_observation.dart';

/// The completed native mode, with observations captured under writer ownership.
enum SyncMode { initialScan, revealedScripts, discovery, liquid }

final class SyncCompletion {
  final SyncMode mode;
  final Duration elapsed;
  final String? _cacheDiagnostics;
  final WalletRevision? revision;
  final Set<String>? incomingTxids;

  const SyncCompletion(
    this.mode,
    this.elapsed, {
    this.revision,
    this.incomingTxids,
  }) : _cacheDiagnostics = null;

  const SyncCompletion._withCache(
    this.mode,
    this.elapsed,
    this._cacheDiagnostics,
    this.incomingTxids, [
    this.revision,
  ]);

  SyncCompletion committed(WalletRevision stamp) => SyncCompletion._withCache(
    mode,
    elapsed,
    _cacheDiagnostics,
    incomingTxids,
    stamp,
  );
}

final class SyncFinished {
  final WalletKey key;
  final Result<SyncCompletion, TransactionSyncFailure> result;

  const SyncFinished(this.key, this.result);
}

/// One Electrum operation inside the writer lease. Headless callers cannot provision or reconcile.
final class ElectrumSync {
  final WalletConnectionPolicy _connections;
  final Future<Result<WalletRevisionState, TransactionSyncFailure>> Function(
    WalletKey,
  )?
  _readRevision;
  final Future<Result<void, TransactionSyncFailure>> Function(SyncCompletion)?
  _onCompletion;
  final Future<String> Function() _documentsDirectory;
  final _active =
      <WalletKey, Future<Result<SyncCompletion, TransactionSyncFailure>>>{};
  final _failures = <WalletKey, Type>{};
  final _started = StreamController<WalletKey>.broadcast();
  final _finished = StreamController<SyncFinished>.broadcast();

  ElectrumSync({
    required this._connections,
    required this._documentsDirectory,
    this._readRevision,
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
    bool headless = false,
    bool allowInitialScan = true,
    Future<Result<void, TransactionSyncFailure>> Function(SyncCompletion)?
    onCompletion,
  }) {
    final key = descriptor.key;
    final previous = _active[key];
    if (previous != null && !discover) return previous;
    // A discovery request must not disappear behind a routine sync. Queue it after the current operation; all native access still happens in workers.
    final completer =
        Completer<Result<SyncCompletion, TransactionSyncFailure>>();
    _active[key] = completer.future;
    unawaited(() async {
      try {
        if (previous != null) await previous;
        final watch = Stopwatch()..start();
        log.fine(
          'Electrum sync started network=${key.network.runtimeType}/${key.network.env.name} discovery=$discover',
        );
        _started.add(key);
        var connectionSummary = 'route=unselected';
        final result = await _run(
          descriptor,
          discover: discover,
          headless: headless,
          allowInitialScan: allowInitialScan,
          onCompletion: onCompletion ?? _onCompletion,
          onConnection: (connection) {
            connectionSummary =
                'route=${descriptor is LiquidWalletDescriptor || connection.socks5?.isNotEmpty != true ? 'direct' : 'proxy'} stop_gap=${connection.stopGap}';
          },
        );
        switch (result) {
          case Ok(:final value):
            if (_failures.remove(key) != null) {
              log.fine('Electrum sync recovered');
            }
            log.fine(
              'Electrum sync finished mode=${value.mode.name} elapsed_ms=${watch.elapsedMilliseconds} $connectionSummary ${value._cacheDiagnostics ?? ''}',
            );
          case Err(:final failure):
            log.fine(
              'Electrum sync finished outcome=failure elapsed_ms=${watch.elapsedMilliseconds} $connectionSummary',
            );
            final previousFailure = _failures[key];
            _failures[key] = failure.runtimeType;
            if (previousFailure != failure.runtimeType) {
              log.warning(
                'Electrum sync failed category=${failure.runtimeType} elapsed_ms=${watch.elapsedMilliseconds}',
              );
            }
        }
        _finished.add(SyncFinished(key, result));
        completer.complete(result);
      } catch (error) {
        log.severe(
          message: 'Electrum sync unexpected failure',
          error: error.runtimeType.toString(),
          trace: StackTrace.empty,
        );
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
    required bool discover,
    required bool headless,
    required bool allowInitialScan,
    required Future<Result<void, TransactionSyncFailure>> Function(
      SyncCompletion,
    )?
    onCompletion,
    required void Function(WalletConnection) onConnection,
  }) async {
    final String root;
    try {
      root = await _documentsDirectory();
    } on Exception {
      return const Err(TransactionSyncStorageFailure());
    }
    final readRevision = _readRevision;
    final Result<WalletRevisionState, TransactionSyncFailure> state;
    if (readRevision != null) {
      state = await readRevision(descriptor.key);
    } else {
      final revisions = RevisionStore(writerMetadataPath(root));
      try {
        state = await revisions.read(descriptor.key);
      } finally {
        await revisions.close();
      }
    }
    final int generation;
    switch (state) {
      case Ok(:final value):
        generation = value.stamp.generation;
      case Err(failure: TransactionSyncNotFoundFailure()):
        generation = 0;
      case Err(:final failure):
        return Err(failure);
    }
    var retryable = false;
    var attempts = 0;
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
          if (attempts++ > 0) {
            log.warning('Electrum sync connection fallback');
          }
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
            ),
          );
          retryable = attempt.retryable;
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
  );

  void observationWarning(String message) =>
      diagnostics.send((WriterLogLevel.warning, message));
}

typedef _Attempt = ({
  Result<SyncCompletion, TransactionSyncFailure> result,
  bool retryable,
});

Future<_Attempt> _performSync(_SyncParams params) async {
  final key = params.descriptor.key;
  if (key.network.env != NetworkEnv.mainnet &&
      key.network.env != NetworkEnv.testnet) {
    return (
      result: const Err<SyncCompletion, TransactionSyncFailure>(
        TransactionSyncUnsupportedNetworkFailure(),
      ),
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
    return (
      result: const Err<SyncCompletion, TransactionSyncFailure>(
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
    return (
      result: const Err<SyncCompletion, TransactionSyncFailure>(
        TransactionSyncConnectionFailure(),
      ),
      retryable: true,
    );
  } finally {
    probe?.dispose();
  }
  if (params.descriptor is LiquidWalletDescriptor) await BullSdk.init();
  final revisions = RevisionStore(writerMetadataPath(params.root));
  final writer = NativeWalletWriter(
    lockDirectory: writerLockDirectory(params.root),
    revisions: revisions,
    documentsDirectory: params.root,
    catalog: _DescriptorCatalog(params.descriptor),
    reservedAddresses: _NoReceiveReservations(),
    diagnostics: (level, message) => params.diagnostics.send((level, message)),
  );
  try {
    final current = await revisions.read(params.descriptor.key);
    if (current case Ok(
      value: final state,
    ) when state.lifecycle == WalletLifecycle.deleted) {
      return (
        result: const Err<SyncCompletion, TransactionSyncFailure>(
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
        return (
          result: const Err<SyncCompletion, TransactionSyncFailure>(
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
        return (
          result: Err<SyncCompletion, TransactionSyncFailure>(failure),
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
      Err(:final failure) => (
        result: Err<SyncCompletion, TransactionSyncFailure>(failure),
        retryable: false,
      ),
      Ok(:final value) => (
        result:
            operation.result?.map(
              (completion) => completion.committed(value.revision),
            ) ??
            const Err<SyncCompletion, TransactionSyncFailure>(
              TransactionSyncStorageFailure(),
            ),
        retryable: false,
      ),
    };
  } finally {
    await revisions.close();
    // Same-port ordering plus acknowledgement drains all diagnostics before
    // compute returns and the foreground closes its listener.
    final acknowledged = ReceivePort();
    params.diagnostics.send(acknowledged.sendPort);
    await acknowledged.first;
    acknowledged.close();
  }
}

final class _NativeSyncOperation
    implements WriterSyncOperation, WriterSyncMutation {
  @override
  bool mayHaveMutated = false;
  final _SyncParams params;
  Result<SyncCompletion, TransactionSyncFailure>? result;
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
    );
    result = attempt.result;
    return switch (attempt.result) {
      Ok() => const Ok(null),
      Err(:final failure) => Err(failure),
    };
  }
}

final class _DescriptorCatalog implements WalletCatalogPort {
  final PublicWalletDescriptor descriptor;
  _DescriptorCatalog(this.descriptor);
  @override
  Future<Result<PublicWalletDescriptor, TransactionSyncFailure>> find(
    WalletKey key,
  ) async => key == descriptor.key
      ? Ok(descriptor)
      : const Err(TransactionSyncNotFoundFailure());
  @override
  Future<Result<List<PublicWalletDescriptor>, TransactionSyncFailure>>
  list() async => Ok([descriptor]);
}

final class _NoReceiveReservations implements ReservedAddressPort {
  @override
  Future<Result<bool, TransactionSyncFailure>> isReserved(
    WalletKey key,
    String address,
  ) => throw StateError('Sync cannot issue receive addresses');
}

Future<_Attempt> _performNativeSync(
  _SyncParams params,
  int? issuedReceiveIndex,
  void Function() markMutation,
) async {
  final watch = Stopwatch()..start();
  final descriptor = params.descriptor;
  final connection = params.connection;
  final path = nativeWalletStoragePath(params.root, descriptor.key);
  if (descriptor is LiquidWalletDescriptor) {
    if (!Directory(path).existsSync()) {
      return (
        result: const Err<SyncCompletion, TransactionSyncFailure>(
          TransactionSyncNotFoundFailure(),
        ),
        retryable: false,
      );
    }
    final network = switch (descriptor.key.network) {
      LiquidNetwork.mainnet => lwk.LiquidNetwork.mainnet,
      LiquidNetwork.testnet => lwk.LiquidNetwork.testnet,
      _ => null,
    };
    if (network == null) {
      return (
        result: const Err<SyncCompletion, TransactionSyncFailure>(
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
      return (
        result: Ok<SyncCompletion, TransactionSyncFailure>(
          SyncCompletion(
            SyncMode.liquid,
            watch.elapsed,
            incomingTxids: incoming,
          ),
        ),
        retryable: false,
      );
    } on lwk.LwkError catch (error) {
      return (
        result: Err<SyncCompletion, TransactionSyncFailure>(
          error.msg.contains('UpdateOnDifferentStatus')
              ? const TransactionSyncNeedsRepairFailure()
              : failure,
        ),
        retryable: false,
      );
    } on Exception {
      return (
        result: Err<SyncCompletion, TransactionSyncFailure>(failure),
        retryable: false,
      );
    } finally {
      wallet?.dispose();
    }
  }
  if (descriptor is! BitcoinWalletDescriptor) {
    return (
      result: const Err<SyncCompletion, TransactionSyncFailure>(
        TransactionSyncInvalidCatalogFailure(),
      ),
      retryable: false,
    );
  }
  final kind = switch (descriptor.key.network) {
    BitcoinNetwork.mainnet => bdk.NetworkKind.main,
    BitcoinNetwork.testnet => bdk.NetworkKind.test,
    _ => null,
  };
  if (kind == null) {
    return (
      result: const Err<SyncCompletion, TransactionSyncFailure>(
        TransactionSyncUnsupportedNetworkFailure(),
      ),
      retryable: false,
    );
  }
  if (!File(path).existsSync()) {
    return (
      result: const Err<SyncCompletion, TransactionSyncFailure>(
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
  BdkElectrumCache? cache;
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
    final checkpoint = wallet.latestCheckpoint();
    final height = checkpoint.height;
    checkpoint.hash.dispose();
    final mode = params.discover
        ? SyncMode.discovery
        : height == 0
        ? SyncMode.initialScan
        : SyncMode.revealedScripts;
    cache = BdkElectrumCache.open(path);
    final prefill = cache?.prefill(client, wallet);
    failure = const TransactionSyncConnectionFailure();
    final batchSize = (connection.stopGap ~/ 4).clamp(50, 1000);
    final bdk.Update update;
    if (mode == SyncMode.revealedScripts) {
      final builder = wallet.startSyncWithRevealedSpks();
      bdk.SyncRequest? request;
      try {
        request = builder.build();
        update = client.sync_(
          request: request,
          batchSize: batchSize,
          fetchPrevTxouts: true,
        );
      } finally {
        request?.dispose();
        builder.dispose();
      }
    } else {
      final builder = wallet.startFullScan();
      bdk.FullScanRequest? request;
      try {
        request = builder.build();
        update = client.fullScan(
          request: request,
          stopGap: connection.stopGap,
          batchSize: batchSize,
          fetchPrevTxouts: true,
        );
      } finally {
        request?.dispose();
        builder.dispose();
      }
    }
    failure = const TransactionSyncStorageFailure();
    try {
      markMutation();
      wallet.applyUpdate(update: update);
      wallet.persist(persister: persister);
    } finally {
      update.dispose();
    }
    final parents = cache?.rememberParents(client, wallet);
    final syncedWallet = wallet;
    final incoming = params.observePayments
        ? await collectPaymentObservation(
            () => _bitcoinIncoming(syncedWallet),
            warning: params.observationWarning,
          )
        : null;
    return (
      result: Ok<SyncCompletion, TransactionSyncFailure>(
        SyncCompletion._withCache(
          mode,
          watch.elapsed,
          BdkElectrumCache.describe(
            opened: cache != null,
            rebuilt: cache?.rebuilt ?? false,
            prefill: prefill,
            parents: parents,
          ),
          incoming,
        ),
      ),
      retryable: false,
    );
  } on Exception {
    return (
      result: Err<SyncCompletion, TransactionSyncFailure>(failure),
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
