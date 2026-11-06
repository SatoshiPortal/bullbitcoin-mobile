import 'dart:async';
import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bull_sdk/bull_sdk.dart' show BullSdk;
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/transaction_sync_failure.dart';
import '../domain/wallet_catalog_port.dart';
import '../domain/wallet_connection_policy.dart';
import '../domain/wallet_key.dart';
import 'bdk_electrum_cache.dart';

/// No durable revision is claimed until the writer protocol lands in lane D.
enum SyncMode { initialScan, revealedScripts, discovery, liquid }

final class SyncCompletion {
  final SyncMode mode;
  final Duration elapsed;
  final String? _cacheDiagnostics;

  const SyncCompletion(this.mode, this.elapsed) : _cacheDiagnostics = null;

  const SyncCompletion._withCache(
    this.mode,
    this.elapsed,
    this._cacheDiagnostics,
  );
}

final class SyncFinished {
  final WalletKey key;
  final Result<SyncCompletion, TransactionSyncFailure> result;

  const SyncFinished(this.key, this.result);
}

/// One foreground Electrum operation. The caller must provision the native store first. No create, repair, reveal, durable revision or background lease.
final class ElectrumSync {
  final WalletConnectionPolicy _connections;
  final Future<String> Function() _documentsDirectory;
  final _active =
      <WalletKey, Future<Result<SyncCompletion, TransactionSyncFailure>>>{};
  final _failures = <WalletKey, Type>{};
  final _started = StreamController<WalletKey>.broadcast();
  final _finished = StreamController<SyncFinished>.broadcast();

  ElectrumSync({required this._connections, required this._documentsDirectory});

  Stream<WalletKey> get started => _started.stream;
  Stream<SyncFinished> get finished => _finished.stream;

  bool isSyncing({String? walletId}) => walletId == null
      ? _active.isNotEmpty
      : _active.keys.any((key) => key.id == walletId);

  @useResult
  Future<Result<SyncCompletion, TransactionSyncFailure>> execute(
    PublicWalletDescriptor descriptor, {
    bool discover = false,
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
        final result = await _run(descriptor, discover: discover);
        switch (result) {
          case Ok(:final value):
            if (_failures.remove(key) != null) {
              log.fine('Electrum sync recovered');
            }
            log.fine(
              'Electrum sync finished mode=${value.mode.name} elapsed_ms=${watch.elapsedMilliseconds} ${value._cacheDiagnostics ?? ''}',
            );
          case Err(:final failure):
            log.fine(
              'Electrum sync finished outcome=failure elapsed_ms=${watch.elapsedMilliseconds}',
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
      } catch (error, stack) {
        completer.completeError(error, stack);
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
  }) async {
    final String root;
    try {
      root = await _documentsDirectory();
    } on Exception {
      return const Err(TransactionSyncStorageFailure());
    }
    var retryable = false;
    var attempts = 0;
    return _connections.run(
      network: descriptor.key.network,
      mayRetry: (_) => retryable,
      operation: (connection) async {
        if (attempts++ > 0) {
          log.warning('Electrum sync connection fallback');
        }
        log.config(
          'Electrum sync connection network=${descriptor.key.network.runtimeType}/${descriptor.key.network.env.name} route=${connection.socks5?.isNotEmpty == true ? 'proxy' : 'direct'} stop_gap=${connection.stopGap}',
        );
        final attempt = await compute(
          _performSync,
          _SyncParams(descriptor, root, connection, discover),
        );
        retryable = attempt.retryable;
        return attempt.result;
      },
    );
  }
}

final class _SyncParams {
  final PublicWalletDescriptor descriptor;
  final String root;
  final WalletConnection connection;
  final bool discover;

  const _SyncParams(this.descriptor, this.root, this.connection, this.discover);
}

typedef _Attempt = ({
  Result<SyncCompletion, TransactionSyncFailure> result,
  bool retryable,
});

Future<_Attempt> _performSync(_SyncParams params) async {
  final watch = Stopwatch()..start();
  final descriptor = params.descriptor;
  final connection = params.connection;
  final path = nativeWalletStoragePath(params.root, descriptor.key);
  if (descriptor is LiquidWalletDescriptor) {
    // The pinned LWK API has no SOCKS argument. Never silently replace a policy-supplied private route with a direct connection.
    if (connection.socks5?.isNotEmpty == true) {
      return (
        result: const Err<SyncCompletion, TransactionSyncFailure>(
          TransactionSyncConnectionFailure(),
        ),
        retryable: false,
      );
    }
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
    bdk.ElectrumClient? probe;
    try {
      // Protocol-only preflight: no descriptor, chain query or native store. LWK opens its own connection after this; a later failure is not retried.
      probe = _connect(connection);
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
    lwk.Wallet? wallet;
    TransactionSyncFailure failure = const TransactionSyncStorageFailure();
    try {
      await BullSdk.init();
      // LWK init may mutate its cache. Never fallback once it has been called.
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
      );
      return (
        result: Ok<SyncCompletion, TransactionSyncFailure>(
          SyncCompletion(SyncMode.liquid, watch.elapsed),
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
    client.ping();
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
      wallet.applyUpdate(update: update);
      wallet.persist(persister: persister);
    } finally {
      update.dispose();
    }
    final parents = cache?.rememberParents(client, wallet);
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

bdk.ElectrumClient _connect(WalletConnection connection) {
  bdk.ElectrumClient build() => bdk.ElectrumClient(
    url: connection.url,
    socks5: connection.socks5?.isNotEmpty == true ? connection.socks5 : null,
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
