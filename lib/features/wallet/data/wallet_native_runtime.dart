import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'dart:async';
import 'dart:io';
import 'package:meta/meta.dart';

import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_model.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:primitives/primitives.dart';
import 'package:sync/read.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart';

import 'wallet_catalog_port_impl.dart';
import '../domain/wallet_spend_failure.dart';

/// Owns application lifecycle orchestration; the shell only composes this owner.
/// The repository compensates catalog insertion on native creation failure.
/// Process death before compensation leaves the row for startup to resume;
/// secrets and native recovery state are retained.
abstract interface class WalletNativeLifecycle {
  Future<void> prepareCreate(WalletMetadataModel metadata);
  Future<void> create(WalletMetadataModel metadata);
  Future<void> delete(WalletMetadataModel metadata);
  Future<void> catalogDeleted(WalletMetadataModel metadata);
  Future<int?> issuedReceiveIndex(WalletMetadataModel metadata);
  Future<({String address, int index})> receive(
    WalletMetadataModel metadata, {
    bool advance = false,
  });
}

final class WalletNativeRuntime implements WalletNativeLifecycle {
  final WalletCatalogPort _catalog;
  final ReservedAddressPort _reserved;
  final WalletMetadataDatasource _metadata;
  final ElectrumSync _sync;
  final Future<String> Function() _documentsDirectory;
  final _changes = StreamController<WalletRevisionState>.broadcast();
  final _unavailable = <WalletKey, TransactionSyncFailure>{};
  Future<_NativeServices>? _opening;
  Future<void>? _initialization;
  Type? _initializationFailure;
  final void Function(ForegroundStores)? _onStoresOpened;

  WalletNativeRuntime({
    required this._catalog,
    required this._reserved,
    required this._metadata,
    required this._sync,
    required this._documentsDirectory,
    @visibleForTesting this._onStoresOpened,
  });

  Stream<WalletRevisionState> get changes => _changes.stream;

  Future<Result<WalletRevisionState, TransactionSyncFailure>> readRevision(
    WalletKey key,
  ) async => (await _services).stores.revisions.read(key);

  Future<_NativeServices> get _services =>
      _opening ??= _open().catchError((Object error, StackTrace trace) {
        _opening = null;
        Error.throwWithStackTrace(error, trace);
      });

  Future<_NativeServices> _open() async {
    final stores = openForeground(
      documentsDirectory: await _documentsDirectory(),
      catalog: _catalog,
      reservedAddresses: _reserved,
    );
    StreamSubscription<WalletRevisionState>? subscription;
    try {
      subscription = stores.changes.listen(_changes.add);
      // Inject a failure after acquiring resources to verify cleanup in tests.
      _onStoresOpened?.call(stores);
      return _NativeServices(stores, subscription);
    } catch (_) {
      try {
        await subscription?.cancel();
      } finally {
        await stores.close();
      }
      rethrow;
    }
  }

  Future<void> initialize() => _initialization ??= _initializeSafely();

  Future<void> _initializeSafely() async {
    try {
      await _initialize();
      _initializationFailure = null;
    } catch (error) {
      _initialization = null;
      if (_initializationFailure != error.runtimeType) {
        _initializationFailure = error.runtimeType;
        log.warning(
          'Native wallet initialization unavailable category=${error is WalletSnapshotException ? error.failure.logCode : 'storage'}',
        );
      }
    }
  }

  /// Explicit provisioning retry; ordinary readers never trigger this pass.
  Future<void> resumeProvisioning() async {
    await initialize();
    _initialization = null;
    await initialize();
  }

  Future<void> _initialize() async {
    final services = await _services;
    final descriptors = _value(await _catalog.list());
    final catalogKeys = descriptors.map((descriptor) => descriptor.key).toSet();
    _unavailable.removeWhere((key, _) => !catalogKeys.contains(key));
    for (final descriptor in descriptors) {
      try {
        final state = await _state(services, descriptor.key);
        if (state?.lifecycle == WalletLifecycle.deleted) {
          // A crash after the tombstone but before catalog removal must not resurrect.
          final result = await services.writer.delete(
            descriptor.key,
            expectedGeneration: state?.stamp.generation ?? 0,
          );
          if (result is Ok) {
            await _metadata.delete(descriptor.key.id);
          } else if (result case Err(:final failure)) {
            _unavailable[descriptor.key] = failure;
          }
          continue;
        }
        // A catalog-only row is resumable provisioning. Existing stores are always
        // adopted with load; only the writer may rebuild a known missing store.
        final path = nativeWalletStoragePath(
          services.stores.documentsDirectory,
          descriptor.key,
        );
        final existing =
            FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;
        var result = await services.writer.create(
          descriptor.key,
          expectedGeneration: state?.stamp.generation ?? 0,
          existingOnly: services.stores.recoveredMetadata || existing,
        );
        if (result case Err(failure: TransactionSyncNeedsRepairFailure())) {
          result = await services.writer.repair(
            descriptor.key,
            expectedGeneration: state?.stamp.generation ?? 0,
          );
          if (result is Ok) {
            final synced = await _sync.execute(descriptor);
            if (synced case Err(:final failure)) {
              _unavailable[descriptor.key] = failure;
            }
            await refresh(descriptor.key);
          }
        }
        if (result case Err(:final failure)) {
          _unavailable[descriptor.key] = failure;
        } else {
          _unavailable.remove(descriptor.key);
        }
      } catch (error) {
        _unavailable[descriptor.key] = error is WalletSnapshotException
            ? error.failure
            : const TransactionSyncStorageFailure();
        log.warning(
          'Native wallet unavailable network=${descriptor.key.network} category=${error is WalletSnapshotException ? error.failure.logCode : 'storage'}',
        );
      }
    }
    if (services.stores.recoveredMetadata) {
      // Every catalog entry has an outcome. completeRecovery durably invalidates
      // all retained spend observations before removing the global barrier,
      // including obligations whose native store could not be adopted.
      services.stores.completeRecovery();
    }
    log.fine(
      'Native wallet initialization finished count=${descriptors.length} unavailable=${_unavailable.length}',
    );
  }

  Future<WalletRevisionState?> _state(
    _NativeServices services,
    WalletKey key,
  ) async => switch (await services.stores.revisions.read(key)) {
    Ok(:final value) => value,
    Err(failure: TransactionSyncNotFoundFailure()) => null,
    Err(:final failure) => throw WalletSnapshotException(failure),
  };

  @override
  Future<void> prepareCreate(WalletMetadataModel metadata) async {
    final descriptor = _value(
      WalletCatalogPortImpl.descriptorFromMetadata(metadata),
    );
    final services = await _services;
    final state = await _state(services, descriptor.key);
    if (state != null && state.lifecycle == WalletLifecycle.deleted) {
      _value(
        await services.writer.prepareReimport(
          descriptor.key,
          expectedGeneration: state.stamp.generation,
        ),
      );
    }
  }

  @override
  Future<void> create(WalletMetadataModel metadata) async {
    final descriptor = _value(
      WalletCatalogPortImpl.descriptorFromMetadata(metadata),
    );
    final services = await _services;
    final state = await _state(services, descriptor.key);
    _value(
      await services.writer.create(
        descriptor.key,
        expectedGeneration: state?.stamp.generation ?? 0,
      ),
    );
    _unavailable.remove(descriptor.key);
  }

  @override
  Future<void> delete(WalletMetadataModel metadata) async {
    final descriptor = _value(
      WalletCatalogPortImpl.descriptorFromMetadata(metadata),
    );
    final services = await _services;
    final state = await _state(services, descriptor.key);
    _value(
      await services.writer.delete(
        descriptor.key,
        expectedGeneration: state?.stamp.generation ?? 0,
      ),
    );
    _unavailable.remove(descriptor.key);
  }

  @override
  Future<({String address, int index})> receive(
    WalletMetadataModel metadata, {
    bool advance = false,
  }) async {
    await initialize();
    final descriptor = _value(
      WalletCatalogPortImpl.descriptorFromMetadata(metadata),
    );
    final services = await _services;
    final state = await _state(services, descriptor.key);
    final issued = _value(
      await services.writer.receive(
        descriptor.key,
        expectedGeneration: state?.stamp.generation ?? 0,
        advance: advance,
      ),
    );
    return (address: issued.address, index: issued.index);
  }

  @override
  Future<int?> issuedReceiveIndex(WalletMetadataModel metadata) async {
    final descriptor = _value(
      WalletCatalogPortImpl.descriptorFromMetadata(metadata),
    );
    final state = await _state(await _services, descriptor.key);
    if (state?.lifecycle == WalletLifecycle.deleted) {
      throw const WalletSnapshotException(TransactionSyncNotFoundFailure());
    }
    return state?.issuedReceiveIndex;
  }

  Future<BitcoinSpendGate> get _spendGate async =>
      (await _services).stores.spendGate;

  Future<WalletKey> _spendKey(String walletId) async {
    final metadata = await _metadata.fetch(walletId);
    if (metadata == null || !metadata.isBitcoin) {
      throw const WalletSpendBlockedException(BitcoinSpendStatus.unavailable);
    }
    return WalletKey(id: walletId, network: metadata.network.shared);
  }

  Future<BitcoinSpendStatus> spendStatus(
    String walletId, {
    String? replacing,
  }) async {
    try {
      return (await _spendGate).check(
        await _spendKey(walletId),
        replacing: replacing,
      );
    } on Exception {
      return BitcoinSpendStatus.unavailable;
    }
  }

  Future<WalletRevision> requireSpend(
    String walletId, {
    String? replacing,
  }) async {
    final admission = await (await _spendGate).acquire(
      await _spendKey(walletId),
      replacing: replacing,
    );
    if (admission case BitcoinSpendRefused(:final status)) {
      throw WalletSpendBlockedException(status);
    }
    final lease = admission as BitcoinSpendAdmission;
    try {
      return lease.revision;
    } finally {
      lease.close();
    }
  }

  Future<Result<BitcoinBroadcastReceipt, WalletSpendFailure>> broadcastBitcoin(
    String walletId,
    BitcoinNetwork network,
    Future<String> Function() broadcast,
  ) async {
    final key = await _spendKey(walletId);
    if (key.network != network) {
      return const Err(
        WalletSpendBlockedFailure(BitcoinSpendStatus.unavailable),
      );
    }
    final admission = await (await _spendGate).acquire(key);
    if (admission case BitcoinSpendRefused(:final status)) {
      return Err(WalletSpendBlockedFailure(status));
    }
    final lease = admission as BitcoinSpendAdmission;
    var accepted = false;
    try {
      final txid = await broadcast();
      accepted = true;
      final receipt = lease.accepted(txid);
      if (!receipt.durable) {
        log.warning(
          'Bitcoin accepted spend recording pending category=storage',
        );
      }
      if (receipt.durable) log.fine('Bitcoin accepted spend recorded');
      return Ok(receipt);
    } finally {
      try {
        lease.close();
      } on Exception {
        if (!accepted) rethrow;
        log.warning('Bitcoin accepted spend cleanup pending category=storage');
      }
    }
  }

  /// Called before a Payjoin terminal transition releases owned-input guards.
  Future<bool> protectObservedSpend(String walletId, String txid) async {
    try {
      final admission = await (await _spendGate).acquire(
        await _spendKey(walletId),
        handoff: true,
      );
      if (admission is! BitcoinSpendAdmission) return false;
      try {
        return admission.accepted(txid).durable;
      } finally {
        admission.close();
      }
    } on Exception {
      return false;
    }
  }

  Future<bdk.Wallet> bitcoin(WalletModel model) async =>
      _borrow<bdk.Wallet>(model);
  Future<lwk.Wallet> liquid(WalletModel model) async =>
      _borrow<lwk.Wallet>(model);

  Future<T> _borrow<T extends Object>(WalletModel model) async {
    await initialize();
    final key = WalletKey(id: model.id, network: model.network.shared);
    final failure = _unavailable[key];
    if (failure != null) throw WalletSnapshotException(failure);
    return (await _services).stores.reader.borrowedHandle<T>(key, _catalog);
  }

  /// Called after every worker outcome, including interrupted/failed writes.
  Future<void> refresh(WalletKey key, {bool catalogChanged = false}) async {
    final services = await _services;
    final state = await services.stores.revisions.read(key);
    if (state case Ok(:final value) when catalogChanged) {
      _changes.add(value);
    }
    if (state case Ok(
      value: final value,
    ) when value.lifecycle == WalletLifecycle.active) {
      _unavailable.remove(key);
    }
  }

  @override
  Future<void> catalogDeleted(WalletMetadataModel metadata) async {
    final descriptor = _value(
      WalletCatalogPortImpl.descriptorFromMetadata(metadata),
    );
    await refresh(descriptor.key, catalogChanged: true);
  }

  Future<void> refreshAll() async {
    final descriptors = _value(await _catalog.list());
    for (final descriptor in descriptors) {
      await refresh(descriptor.key);
    }
  }

  Future<void> repair(WalletKey key) async {
    final services = await _services;
    final state = await _state(services, key);
    _value(
      await services.writer.repair(
        key,
        expectedGeneration: state?.stamp.generation ?? 0,
      ),
    );
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening != null) {
      final services = await opening;
      try {
        await services.subscription.cancel();
      } finally {
        await services.stores.close();
      }
    }
    await _changes.close();
  }

  static T _value<T>(Result<T, TransactionSyncFailure> result) =>
      switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => throw WalletSnapshotException(failure),
      };
}

final class _NativeServices {
  final ForegroundStores stores;
  final StreamSubscription<WalletRevisionState> subscription;
  _NativeServices(this.stores, this.subscription);

  WalletWriterRepository get writer => stores.writer;
}
