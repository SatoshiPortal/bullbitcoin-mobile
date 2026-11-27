import '../lease_diagnostics.dart';

import 'dart:io';

import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:rust_bindings/lwk.dart' as lwk;
import 'package:primitives/primitives.dart';
import 'package:bull_logger/bull_logger.dart';

import '../../domain/ports/wallet_read_readiness_port.dart';

import '../../domain/sync_failure.dart';
import '../../domain/native_network_policy.dart';
import '../../domain/public_wallet_descriptor.dart';
import '../../domain/ports/wallet_catalog_port.dart';
import '../../domain/wallet_key.dart';
import '../native_store_paths.dart';
import '../write/datasources/native_store_errors.dart';
import '../../domain/wallet_revision.dart';
import '../../domain/ports/read_admission_port.dart';
import '../../domain/ports/wallet_revision_reader_port.dart';

/// A borrowed native handle hydrated from a writer-initialized store.
/// Consumers must not mutate, dispose or persist this shared reader handle.
final class WalletReadSnapshot<T> {
  final T wallet;
  final WalletRevision revision;

  /// The data may be behind: its sync failed, or the writer held the wallet.
  final bool stale;

  /// Proven under the read admission to be the committed revision. False for
  /// a cache served while the writer held the wallet, whatever [stale] says:
  /// a failed sync is stale but admitted.
  final bool admitted;

  const WalletReadSnapshot(
    this.wallet,
    this.revision, {
    this.stale = false,
    this.admitted = false,
  });
}

/// Hydrates existing stores only after the writer attests their current schema.
/// SDK handles are borrowed read-only; the SDK finalizers own their lifetime.
/// Production activation requires D's real revision/readiness/admission ports.
final class WalletSnapshotReader {
  final String documentsDirectory;
  final WalletReadReadinessPort readiness;
  final int requiredSchemaVersion;
  final void Function(Object) _disposeUnpublished;
  final Map<WalletKey, String> _diagnostics = {};
  final WalletRevisionReaderPort revisions;
  final ReadAdmissionPort liquidAdmission;
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
    this._disposeUnpublished = _disposeNative,
  });

  static void _disposeNative(Object wallet) {
    if (wallet is bdk.Wallet) wallet.dispose();
    if (wallet is lwk.Wallet) wallet.dispose();
  }

  /// Looks up the canonical descriptor without importing application models.
  Future<Result<WalletReadSnapshot<Object>, SyncFailure>> read(
    WalletKey key,
    WalletCatalogPort catalog,
  ) async {
    switch (await catalog.find(key)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (value.key != key) {
          return const Err(SyncInvalidCatalogFailure());
        }
        return switch (value) {
          BitcoinWalletDescriptor() => bitcoin(value),
          LiquidWalletDescriptor() => liquid(value),
        };
    }
  }

  Future<Result<WalletReadSnapshot<bdk.Wallet>, SyncFailure>> bitcoin(
    BitcoinWalletDescriptor descriptor,
  ) => _read<bdk.Wallet>(descriptor, (ready) => _bitcoin(descriptor));

  Future<Result<WalletReadSnapshot<lwk.Wallet>, SyncFailure>> liquid(
    LiquidWalletDescriptor descriptor,
  ) => _read<lwk.Wallet>(descriptor, (ready) => _liquid(descriptor, ready));

  Future<Result<WalletReadSnapshot<T>, SyncFailure>> _read<T extends Object>(
    PublicWalletDescriptor descriptor,
    Future<T> Function(WalletReadReady) hydrate,
  ) async {
    final failure = nativeDescriptorFailure(descriptor);
    if (failure != null) return Err(failure);
    final key = descriptor.key;
    // Serialize hydration/cache publication for the same wallet in this isolate.
    final trace = LeaseDiagnostics(
      role: LeaseRole.reader,
      intent: LeaseIntent.snapshot,
    );
    return _serialize(key, () async {
      final result = await trace.run(
        () => _readAdmitted<T>(descriptor, hydrate),
      );
      final category = switch (result) {
        Ok(:final value) => value.stale ? 'stale' : 'fresh',
        Err(:final failure) => failure.logCode,
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
  }

  Future<R> _serialize<R>(WalletKey key, Future<R> Function() run) async {
    final previous = _pending[key] ?? Future<void>.value();
    final operation = previous.then((_) => run());
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

  /// Strict financial reads share the reader queue, but never publish or use
  /// its native cache. The temporary handle is disposed before lease release.
  Future<Result<BigInt, SyncFailure>> readBalance(
    WalletRevision expected,
    WalletCatalogPort catalog, {
    required bool Function() isCurrent,
    required Future<Result<ReadLease, SyncFailure>> Function(WalletKey)
    acquireExisting,
    required Future<BigInt> Function(Object) map,
    Future<void> Function()? beforeHydration,
  }) async {
    if (!isCurrent()) return const Err(SyncClosedFailure());
    final key = expected.key;
    final lookup = await catalog.find(key);
    if (!isCurrent()) return const Err(SyncClosedFailure());
    if (lookup case Err(:final failure)) return Err(failure);
    final descriptor =
        (lookup as Ok<PublicWalletDescriptor, SyncFailure>).value;
    if (descriptor.key != key) return const Err(SyncInvalidCatalogFailure());
    if (nativeDescriptorFailure(descriptor) case final failure?) {
      return Err(failure);
    }
    return _serialize(key, () async {
      if (!isCurrent()) return const Err(SyncClosedFailure());
      final acquired = await acquireExisting(key);
      if (acquired case Err(:final failure)) {
        return Err(isCurrent() ? failure : const SyncClosedFailure());
      }
      final lease = (acquired as Ok<ReadLease, SyncFailure>).value;
      Object? wallet;
      try {
        if (!isCurrent()) return const Err(SyncClosedFailure());
        if (lease.revision != expected) return const Err(SyncBusyFailure());
        final ready = await readiness.check(
          descriptor,
          expected,
          requiredSchemaVersion,
        );
        if (!isCurrent()) return const Err(SyncClosedFailure());
        if (ready case Err(:final failure)) return Err(failure);
        final proof = (ready as Ok<WalletReadReady, SyncFailure>).value;
        if (proof.revision != expected ||
            proof.schemaVersion != requiredSchemaVersion) {
          return const Err(SyncBusyFailure());
        }
        if (beforeHydration != null) await beforeHydration();
        _checkAdmission(isCurrent);
        final hydrated = switch (descriptor) {
          BitcoinWalletDescriptor() => await _bitcoin(descriptor, isCurrent),
          LiquidWalletDescriptor() => await _liquid(
            descriptor,
            proof,
            isCurrent,
          ),
        };
        wallet = hydrated;
        _checkAdmission(isCurrent);
        final total = await map(hydrated);
        _checkAdmission(isCurrent);
        return Ok(total);
      } on _ReadFailure catch (error) {
        return Err(error.failure);
      } on Exception catch (error) {
        return Err(
          isLiquidStatusConflict(error)
              ? const SyncNeedsRepairFailure()
              : const SyncStorageFailure(),
        );
      } finally {
        try {
          if (wallet != null) _disposeUnpublished(wallet);
        } finally {
          await lease.release();
        }
      }
    });
  }

  static void _checkAdmission(bool Function()? isCurrent) {
    if (isCurrent?.call() == false) {
      throw const _ReadFailure(SyncClosedFailure());
    }
  }

  Future<Result<WalletReadSnapshot<T>, SyncFailure>>
  _readAdmitted<T extends Object>(
    PublicWalletDescriptor descriptor,
    Future<T> Function(WalletReadReady) hydrate,
  ) async {
    final key = descriptor.key;
    final trace = LeaseDiagnostics.current;
    final stateResult = await revisions.read(key);
    if (stateResult case Err(:final failure)) {
      if (failure is SyncBusyFailure) {
        trace?.busy(LeaseBusySource.revisionRead);
      }
      _cache.remove(key);
      return Err(failure);
    }
    final state = (stateResult as Ok<WalletRevisionState, SyncFailure>).value;
    if (state.stamp.key != key || state.lifecycle == WalletLifecycle.deleted) {
      _cache.remove(key);
      return const Err(SyncNotFoundFailure());
    }
    final cached = _cache[key];
    if (cached != null &&
        cached.snapshot.revision.generation != state.stamp.generation) {
      _cache.remove(key);
    }
    WalletReadSnapshot<T>? current;
    final entry = _cache[key];
    if (entry != null && entry.descriptor != _descriptorIdentity(descriptor)) {
      return const Err(SyncInvalidCatalogFailure());
    }
    final candidate = entry?.snapshot;
    if (candidate != null && candidate.wallet is T) {
      current = WalletReadSnapshot(candidate.wallet as T, candidate.revision);
    }
    Future<Result<WalletReadSnapshot<T>, SyncFailure>> busy([
      LeaseBusySource? source,
    ]) async {
      if (trace != null) trace.read = LeaseRead.stale;
      if (source != null) trace?.busy(source);
      final snapshot = current;
      if (snapshot == null) {
        return const Err(SyncBusyFailure());
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
      return const Err(SyncBusyFailure());
    }

    if (state.lifecycle == WalletLifecycle.pendingWrite ||
        state.initializedSchema != requiredSchemaVersion) {
      return await busy(
        state.lifecycle == WalletLifecycle.pendingWrite
            ? LeaseBusySource.lifecycleGate
            : LeaseBusySource.schemaGate,
      );
    }

    ReadLease? lease;
    T? unpublished;
    try {
      {
        switch (await liquidAdmission.acquire(key)) {
          case Err(failure: SyncBusyFailure()):
            return await busy();
          case Err(:final failure):
            return Err(failure);
          case Ok(:final value):
            lease = value;
        }
        if (lease.revision.key != key || lease.revision != state.stamp) {
          return await busy(LeaseBusySource.revisionRead);
        }
      }
      final stamp = lease.revision;
      final readyResult = await readiness.check(
        descriptor,
        stamp,
        requiredSchemaVersion,
      );
      if (readyResult case Err(:final failure)) {
        if (failure is SyncBusyFailure) {
          // Readiness owns the exact gate diagnostic.
          return await busy();
        }
        _cache.remove(key);
        return Err(failure);
      }
      final ready = (readyResult as Ok<WalletReadReady, SyncFailure>).value;
      if (ready.revision != stamp ||
          ready.schemaVersion != requiredSchemaVersion) {
        return await busy(
          ready.revision != stamp
              ? LeaseBusySource.revisionRead
              : LeaseBusySource.schemaGate,
        );
      }
      if (current != null && current.revision == stamp) {
        if (trace != null) trace.read = LeaseRead.cache;
        final latest = await revisions.read(key);
        if (latest case Ok(value: final next)
            when next.lifecycle == WalletLifecycle.active &&
                next.stamp == stamp) {
          if (trace != null && next.syncFailed) trace.read = LeaseRead.stale;
          return Ok(
            WalletReadSnapshot(
              current.wallet,
              current.revision,
              stale: next.syncFailed,
              admitted: true,
            ),
          );
        }
        return await busy(LeaseBusySource.revisionRead);
      }
      final timer = Stopwatch()..start();
      final wallet = await hydrate(ready);
      unpublished = wallet;
      final after = await revisions.read(key);
      if (after case Ok(value: final next)
          when next.lifecycle == WalletLifecycle.active &&
              next.stamp == stamp) {
        log.fine(
          'Wallet reader hydrated: network=${key.network} '
          'generation=${stamp.generation} revision=${stamp.revision} '
          'state=${next.syncFailed ? 'stale' : 'fresh'} reason=${next.syncFailed ? 'sync_failed' : 'none'} duration_ms=${timer.elapsedMilliseconds}',
        );
        if (trace != null && next.syncFailed) trace.read = LeaseRead.stale;
        final snapshot = WalletReadSnapshot<T>(
          wallet,
          stamp,
          stale: next.syncFailed,
          admitted: true,
        );
        _cache[key] = (
          snapshot: WalletReadSnapshot<Object>(wallet, stamp),
          descriptor: _descriptorIdentity(descriptor),
        );
        unpublished = null;
        return Ok(snapshot);
      }
      return await busy(LeaseBusySource.revisionRead);
    } on _ReadFailure catch (e) {
      if (e.failure is SyncBusyFailure) {
        return await busy(LeaseBusySource.schemaGate);
      }
      return Err(e.failure);
    } on FileSystemException {
      return const Err(SyncStorageFailure());
    } catch (e) {
      if (e is Error) {
        rethrow;
      }
      // Only LWK's status conflict calls for a repair; any other native
      // failure is a storage one, which repair would not fix.
      return Err(
        isLiquidStatusConflict(e)
            ? const SyncNeedsRepairFailure()
            : const SyncStorageFailure(),
      );
    } finally {
      try {
        final rejected = unpublished;
        if (rejected != null) _disposeUnpublished(rejected);
      } finally {
        await lease?.release();
      }
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
      throw const _ReadFailure(SyncNotFoundFailure());
    }
    if (actual != type) {
      throw const _ReadFailure(SyncNeedsRepairFailure());
    }
  }

  Future<bdk.Wallet> _bitcoin(
    BitcoinWalletDescriptor descriptor, [
    bool Function()? isCurrent,
  ]) async {
    final network = descriptor.key.network;
    if (network != BitcoinNetwork.mainnet &&
        network != BitcoinNetwork.testnet &&
        network != BitcoinNetwork.regtest) {
      throw const _ReadFailure(SyncUnsupportedNetworkFailure());
    }
    final source = nativeWalletStoragePath(documentsDirectory, descriptor.key);
    await _require(source, FileSystemEntityType.file);
    _checkAdmission(isCurrent);
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
      final wallet = bdk.Wallet.load(
        descriptor: external,
        changeDescriptor: internal,
        persister: persister,
        lookahead: 25,
      );
      final expected = switch (network) {
        BitcoinNetwork.mainnet => bdk.Network.bitcoin,
        BitcoinNetwork.testnet => bdk.Network.testnet,
        BitcoinNetwork.regtest => bdk.Network.regtest,
        _ => throw const _ReadFailure(SyncUnsupportedNetworkFailure()),
      };
      if (wallet.network() != expected) {
        wallet.dispose();
        throw const _ReadFailure(SyncInvalidCatalogFailure());
      }
      return wallet;
    } finally {
      persister.dispose();
      external.dispose();
      internal.dispose();
    }
  }

  Future<lwk.Wallet> _liquid(
    LiquidWalletDescriptor descriptor,
    WalletReadReady ready, [
    bool Function()? isCurrent,
  ]) async {
    final network = switch (descriptor.key.network) {
      LiquidNetwork.mainnet => lwk.LiquidNetwork.mainnet,
      LiquidNetwork.testnet => lwk.LiquidNetwork.testnet,
      LiquidNetwork.regtest => lwk.LiquidNetwork.regtest,
      _ => throw const _ReadFailure(SyncUnsupportedNetworkFailure()),
    };
    final source = nativeWalletStoragePath(documentsDirectory, descriptor.key);
    await _require(source, FileSystemEntityType.directory);
    _checkAdmission(isCurrent);
    // The writer records the SDK's canonical relative path when initializing.
    // Never derive it by calling Wallet.init on an absent directory.
    final relative = ready.liquidCachePath;
    if (relative == null ||
        !RegExp(r'^[a-zA-Z0-9_-]+/enc_cache/[a-fA-F0-9]+$')
            .hasMatch(relative)) {
      throw const _ReadFailure(SyncBusyFailure());
    }
    var checked = source;
    for (final segment in relative.split('/')) {
      checked = '$checked/$segment';
      await _require(checked, FileSystemEntityType.directory);
      _checkAdmission(isCurrent);
    }
    await for (final entry in Directory(checked).list(followLinks: false)) {
      _checkAdmission(isCurrent);
      if (RegExp(r'^[0-9]{12}$').hasMatch(entry.path.split('/').last)) {
        await _require(entry.path, FileSystemEntityType.file);
        _checkAdmission(isCurrent);
      }
    }
    _checkAdmission(isCurrent);
    return lwk.Wallet.init(
      network: network,
      dbpath: source,
      descriptor: lwk.Descriptor(ctDescriptor: descriptor.combinedCtDescriptor),
    );
  }
}

final class _ReadFailure implements Exception {
  final SyncFailure failure;
  const _ReadFailure(this.failure);
}

/// A [SyncFailure] thrown by the app's throwing datasource APIs. Result-based
/// consumers propagate the failure directly.
final class WalletSnapshotException implements Exception {
  final SyncFailure failure;

  const WalletSnapshotException(this.failure);

  @override
  String toString() => 'WalletSnapshotException(${failure.runtimeType})';
}
