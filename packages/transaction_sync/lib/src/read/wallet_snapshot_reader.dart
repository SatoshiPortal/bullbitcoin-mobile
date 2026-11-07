import 'dart:io';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:primitives/primitives.dart';
import 'package:bull_logger/bull_logger.dart';

import 'wallet_read_readiness.dart';

import '../domain/transaction_sync_failure.dart';
import '../domain/wallet_catalog_port.dart';
import '../domain/wallet_key.dart';
import '../domain/wallet_revision.dart';

/// A borrowed native handle hydrated from a writer-initialized store.
/// Consumers must not mutate, dispose or persist this shared reader handle.
final class WalletReadSnapshot<T> {
  final T wallet;
  final WalletRevision revision;
  final bool stale;

  const WalletReadSnapshot(this.wallet, this.revision, {this.stale = false});
}

/// Hydrates existing stores only after the writer attests their current schema.
/// SDK handles are borrowed read-only; the SDK finalizers own their lifetime.
/// Production activation requires D's real revision/readiness/admission ports.
final class WalletSnapshotReader {
  final String documentsDirectory;
  final WalletReadReadiness readiness;
  final int requiredSchemaVersion;
  final Map<WalletKey, String> _diagnostics = {};
  final WalletRevisionReader revisions;
  final LiquidReadAdmission liquidAdmission;
  final Map<
    WalletKey,
    ({WalletReadSnapshot<Object> snapshot, Object descriptor})
  >
  _cache = {};
  final Map<WalletKey, Future<void>> _pending = {};

  WalletSnapshotReader({
    required this.documentsDirectory,
    required this.readiness,
    required this.requiredSchemaVersion,
    required this.revisions,
    required this.liquidAdmission,
  });

  /// Looks up the canonical descriptor without importing application models.
  Future<Result<WalletReadSnapshot<Object>, TransactionSyncFailure>> read(
    WalletKey key,
    WalletCatalogPort catalog,
  ) async {
    switch (await catalog.find(key)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (value.key != key) {
          return const Err(TransactionSyncInvalidCatalogFailure());
        }
        return switch (value) {
          BitcoinWalletDescriptor() => bitcoin(value),
          LiquidWalletDescriptor() => liquid(value),
        };
    }
  }

  /// Bridge for legacy throwing datasource APIs; new consumers use [read].
  Future<T> borrowedHandle<T extends Object>(
    WalletKey key,
    WalletCatalogPort catalog,
  ) async => switch (await read(key, catalog)) {
    Ok(:final value) when value.wallet is T => value.wallet as T,
    Ok() => throw const WalletSnapshotException(
      TransactionSyncInvalidCatalogFailure(),
    ),
    Err(:final failure) => throw WalletSnapshotException(failure),
  };

  Future<Result<WalletReadSnapshot<bdk.Wallet>, TransactionSyncFailure>>
  bitcoin(BitcoinWalletDescriptor descriptor) =>
      _read<bdk.Wallet>(descriptor, (ready) => _bitcoin(descriptor));

  Future<Result<WalletReadSnapshot<lwk.Wallet>, TransactionSyncFailure>> liquid(
    LiquidWalletDescriptor descriptor,
  ) => _read<lwk.Wallet>(descriptor, (ready) => _liquid(descriptor, ready));

  Future<Result<WalletReadSnapshot<T>, TransactionSyncFailure>>
  _read<T extends Object>(
    PublicWalletDescriptor descriptor,
    Future<T> Function(WalletReadReady) hydrate,
  ) async {
    final key = descriptor.key;
    // Serialize hydration/cache publication for the same wallet in this isolate.
    final previous = _pending[key] ?? Future<void>.value();
    final operation = previous.then((_) async {
      final result = await _readAdmitted<T>(descriptor, hydrate);
      final category = switch (result) {
        Ok(:final value) => value.stale ? 'stale' : 'fresh',
        Err(:final failure) => failure.runtimeType.toString(),
      };
      if (_diagnostics[key] != category) {
        _diagnostics[key] = category;
        final message =
            'Wallet reader state: network=${key.network} '
            'state=$category';
        if (result is Err) {
          log.warning(message);
        } else {
          log.fine(message);
        }
      }
      return result;
    });
    final tail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _pending[key] = tail;
    try {
      return await operation;
    } finally {
      if (identical(_pending[key], tail)) {
        _pending.remove(key);
      }
    }
  }

  Future<Result<WalletReadSnapshot<T>, TransactionSyncFailure>>
  _readAdmitted<T extends Object>(
    PublicWalletDescriptor descriptor,
    Future<T> Function(WalletReadReady) hydrate,
  ) async {
    final key = descriptor.key;
    final stateResult = await revisions.read(key);
    if (stateResult case Err(:final failure)) {
      _cache.remove(key);
      return Err(failure);
    }
    final state =
        (stateResult as Ok<WalletRevisionState, TransactionSyncFailure>).value;
    if (state.stamp.key != key || state.lifecycle == WalletLifecycle.deleted) {
      _cache.remove(key);
      return const Err(TransactionSyncNotFoundFailure());
    }
    final cached = _cache[key];
    if (cached != null &&
        cached.snapshot.revision.generation != state.stamp.generation) {
      _cache.remove(key);
    }
    WalletReadSnapshot<T>? current;
    final entry = _cache[key];
    if (entry != null && entry.descriptor != _descriptorIdentity(descriptor)) {
      return const Err(TransactionSyncInvalidCatalogFailure());
    }
    final candidate = entry?.snapshot;
    if (candidate != null && candidate.wallet is T) {
      current = WalletReadSnapshot(candidate.wallet as T, candidate.revision);
    }
    Future<Result<WalletReadSnapshot<T>, TransactionSyncFailure>> busy() async {
      final snapshot = current;
      if (snapshot == null) {
        return const Err(TransactionSyncBusyFailure());
      }
      final latest = await revisions.read(key);
      if (latest case Ok(value: final value)
          when value.stamp.key == key &&
              value.lifecycle != WalletLifecycle.deleted &&
              value.stamp.generation == snapshot.revision.generation) {
        return Ok(
          WalletReadSnapshot(snapshot.wallet, snapshot.revision, stale: true),
        );
      }
      _cache.remove(key);
      return const Err(TransactionSyncBusyFailure());
    }

    if (state.lifecycle == WalletLifecycle.pendingWrite ||
        state.initializedSchema != requiredSchemaVersion) {
      return busy();
    }

    LiquidReadLease? lease;
    try {
      {
        switch (await liquidAdmission.acquire(key)) {
          case Err(failure: TransactionSyncBusyFailure()):
            return busy();
          case Err(:final failure):
            return Err(failure);
          case Ok(:final value):
            lease = value;
        }
        if (lease.revision.key != key || lease.revision != state.stamp) {
          _cache.remove(key);
          return const Err(TransactionSyncBusyFailure());
        }
      }
      final stamp = lease.revision;
      final readyResult = await readiness.check(
        descriptor,
        stamp,
        requiredSchemaVersion,
      );
      if (readyResult case Err(:final failure)) {
        if (failure is TransactionSyncBusyFailure) {
          return busy();
        }
        _cache.remove(key);
        return Err(failure);
      }
      final ready =
          (readyResult as Ok<WalletReadReady, TransactionSyncFailure>).value;
      if (ready.revision != stamp ||
          ready.schemaVersion != requiredSchemaVersion) {
        return busy();
      }
      if (current != null && current.revision == stamp) {
        final latest = await revisions.read(key);
        if (latest case Ok(value: final next)
            when next.lifecycle == WalletLifecycle.active &&
                next.stamp == stamp) {
          return Ok(current);
        }
        return busy();
      }
      final timer = Stopwatch()..start();
      final wallet = await hydrate(ready);
      final after = await revisions.read(key);
      if (after case Ok(
        value: final next,
      ) when next.lifecycle == WalletLifecycle.active && next.stamp == stamp) {
        log.fine(
          'Wallet reader hydrated: network=${key.network} '
          'generation=${stamp.generation} revision=${stamp.revision} '
          'durationMs=${timer.elapsedMilliseconds}',
        );
        final snapshot = WalletReadSnapshot<T>(wallet, stamp);
        _cache[key] = (
          snapshot: WalletReadSnapshot<Object>(wallet, stamp),
          descriptor: _descriptorIdentity(descriptor),
        );
        return Ok(snapshot);
      }
      if (wallet is bdk.Wallet) {
        wallet.dispose();
      }
      if (wallet is lwk.Wallet) {
        wallet.dispose();
      }
      _cache.remove(key);
      return const Err(TransactionSyncBusyFailure());
    } on _ReadFailure catch (e) {
      if (e.failure is TransactionSyncBusyFailure) {
        return busy();
      }
      return Err(e.failure);
    } on FileSystemException {
      return const Err(TransactionSyncStorageFailure());
    } catch (e) {
      if (e is Error) {
        rethrow;
      }
      return const Err(TransactionSyncNeedsRepairFailure());
    } finally {
      await lease?.release();
    }
  }

  Object _descriptorIdentity(PublicWalletDescriptor descriptor) =>
      switch (descriptor) {
        BitcoinWalletDescriptor() => (
          descriptor.externalDescriptor,
          descriptor.internalDescriptor,
        ),
        LiquidWalletDescriptor() => (descriptor.combinedCtDescriptor,),
      };

  Future<void> _require(String path, FileSystemEntityType type) async {
    final actual = await FileSystemEntity.type(path, followLinks: false);
    if (actual == FileSystemEntityType.notFound) {
      throw const _ReadFailure(TransactionSyncNotFoundFailure());
    }
    if (actual != type) {
      throw const _ReadFailure(TransactionSyncNeedsRepairFailure());
    }
  }

  Future<bdk.Wallet> _bitcoin(BitcoinWalletDescriptor descriptor) async {
    final network = descriptor.key.network;
    if (network != BitcoinNetwork.mainnet &&
        network != BitcoinNetwork.testnet) {
      throw const _ReadFailure(TransactionSyncUnsupportedNetworkFailure());
    }
    final source = nativeWalletStoragePath(documentsDirectory, descriptor.key);
    await _require(source, FileSystemEntityType.file);
    final kind = network == BitcoinNetwork.mainnet
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
    final persister = bdk.Persister.newSqlite(path: source);
    try {
      return bdk.Wallet.load(
        descriptor: external,
        changeDescriptor: internal,
        persister: persister,
        lookahead: 25,
      );
    } finally {
      persister.dispose();
      external.dispose();
      internal.dispose();
    }
  }

  Future<lwk.Wallet> _liquid(
    LiquidWalletDescriptor descriptor,
    WalletReadReady ready,
  ) async {
    final network = switch (descriptor.key.network) {
      LiquidNetwork.mainnet => lwk.LiquidNetwork.mainnet,
      LiquidNetwork.testnet => lwk.LiquidNetwork.testnet,
      _ => throw const _ReadFailure(TransactionSyncUnsupportedNetworkFailure()),
    };
    final source = nativeWalletStoragePath(documentsDirectory, descriptor.key);
    await _require(source, FileSystemEntityType.directory);
    // The writer records the SDK's canonical relative path when initializing.
    // Never derive it by calling Wallet.init on an absent directory.
    final relative = ready.liquidCachePath;
    if (relative == null ||
        !RegExp(
          r'^[a-zA-Z0-9_-]+/enc_cache/[a-fA-F0-9]+$',
        ).hasMatch(relative)) {
      throw const _ReadFailure(TransactionSyncBusyFailure());
    }
    var checked = source;
    for (final segment in relative.split('/')) {
      checked = '$checked/$segment';
      await _require(checked, FileSystemEntityType.directory);
    }
    await for (final entry in Directory(checked).list(followLinks: false)) {
      if (RegExp(r'^[0-9]{12}$').hasMatch(entry.path.split('/').last)) {
        await _require(entry.path, FileSystemEntityType.file);
      }
    }
    return lwk.Wallet.init(
      network: network,
      dbpath: source,
      descriptor: lwk.Descriptor(ctDescriptor: descriptor.combinedCtDescriptor),
    );
  }
}

final class _ReadFailure implements Exception {
  final TransactionSyncFailure failure;
  const _ReadFailure(this.failure);
}

/// Transitional exception for legacy datasources whose APIs still throw.
/// Result-based consumers should propagate the reader's failure directly.
final class WalletSnapshotException implements Exception {
  final TransactionSyncFailure failure;

  const WalletSnapshotException(this.failure);

  @override
  String toString() => 'WalletSnapshotException(${failure.runtimeType})';
}
