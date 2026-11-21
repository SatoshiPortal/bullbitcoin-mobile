import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

import '../../../sync.dart' hide Wallet;
import '../../../sync.dart' as sync show Wallet;
import '../../../write.dart';

/// Coordinates provisioning and recovery of native stores. Catalog entries are
/// supplied through [WalletCatalogPort]; their deletion remains with the owner.
abstract interface class WalletNativeLifecycle {
  Future<Result<void, SyncFailure>> prepareCreate(WalletKey key);
  Future<Result<void, SyncFailure>> create(WalletKey key);
  Future<Result<void, SyncFailure>> delete(WalletKey key);
  Future<Result<void, SyncFailure>> catalogDeleted(WalletKey key);
  Future<Result<int?, SyncFailure>> issuedReceiveIndex(WalletKey key);
  Future<Result<({String address, int index}), SyncFailure>> receive(
    WalletKey key, {
    bool advance = false,
  });
}

final class WalletNativeRuntime implements WalletNativeLifecycle {
  final WalletCatalogPort _catalog;
  final ReservedAddressPort _reserved;
  final InputReservationPort _inputReservations;
  final FundingReservationPort? _fundingReservations;
  final Future<Result<void, SyncFailure>> Function(WalletKey)
  _deleteCatalogEntry;
  final ElectrumSync _sync;
  final Future<String> Function() _documentsDirectory;
  final _changes = StreamController<WalletRevisionState>.broadcast();
  final _unavailable = <WalletKey, SyncFailure>{};
  Future<_NativeServices>? _opening;
  Future<void>? _initialization;
  Type? _initializationFailure;
  final void Function(ForegroundStores)? _onStoresOpened;
  final FreezeStorePort _freezes;
  final WalletConnectionPort _connections;

  WalletNativeRuntime.open({
    required this._catalog,
    required this._reserved,
    required this._inputReservations,
    this._fundingReservations,
    required this._deleteCatalogEntry,
    required this._sync,
    required this._documentsDirectory,
    required this._freezes,
    required this._connections,
    @visibleForTesting this._onStoresOpened,
  });

  Future<Result<T, SyncFailure>> _result<T>(
    Future<T> Function() operation,
  ) async {
    try {
      return Ok(await operation());
    } on WalletSnapshotException catch (error) {
      return Err(error.failure);
    } on Exception {
      return const Err(SyncStorageFailure());
    }
  }

  Future<Result<void, SyncFailure>> initialize() => _result(_initialize);
  Future<Result<void, SyncFailure>> resumeProvisioning() =>
      _result(_resumeProvisioning);
  @override
  Future<Result<void, SyncFailure>> prepareCreate(WalletKey key) =>
      _result(() => _prepareCreate(key));
  @override
  Future<Result<void, SyncFailure>> create(WalletKey key) =>
      _result(() => _create(key));
  @override
  Future<Result<void, SyncFailure>> delete(WalletKey key) =>
      _result(() => _delete(key));
  @override
  Future<Result<({String address, int index}), SyncFailure>> receive(
    WalletKey key, {
    bool advance = false,
  }) => _result(() => _receive(key, advance: advance));
  @override
  Future<Result<int?, SyncFailure>> issuedReceiveIndex(WalletKey key) =>
      _result(() => _issuedReceiveIndex(key));
  Future<Result<sync.Wallet, SyncFailure>> wallet(WalletKey key) =>
      _result(() => _wallet(key));
  Future<Result<BitcoinSpendStatus, SyncFailure>> spendStatus(
    WalletKey key, {
    String? replacing,
  }) => _result(() => _spendStatus(key, replacing: replacing));
  Future<Result<bool, SyncFailure>> protectObservedSpend(
    WalletKey key,
    String txid,
  ) => _result(() => _protectObservedSpend(key, txid));
  Future<Result<sync.Wallet, SyncFailure>> loadWallet(WalletKey key) =>
      _result(() => _loadWallet(key));
  Future<Result<Sync, SyncFailure>> foreground() => _result(_foreground);
  Future<Result<void, SyncFailure>> refresh(
    WalletKey key, {
    bool catalogChanged = false,
  }) => _result(() => _refresh(key, catalogChanged: catalogChanged));
  @override
  Future<Result<void, SyncFailure>> catalogDeleted(WalletKey key) =>
      _result(() => _catalogDeleted(key));
  Future<Result<void, SyncFailure>> refreshAll() => _result(_refreshAll);
  Future<Result<void, SyncFailure>> repair(WalletKey key) =>
      _result(() => _repair(key));
  Future<Result<void, SyncFailure>> close() => _result(_close);

  Stream<WalletRevisionState> get changes => _changes.stream;

  /// Privileged wallet composition must bind the exact same durable authority.
  bool usesFundingReservations(FundingReservationPort authority) =>
      identical(_fundingReservations, authority);

  Future<Result<WalletRevisionState, SyncFailure>> readRevision(
    WalletKey key,
  ) async {
    try {
      return await (await _services).stores.revisions.read(key);
    } on Exception {
      return const Err(SyncStorageFailure());
    }
  }

  Future<_NativeServices> get _services =>
      _opening ??= _open().catchError((Object error, StackTrace trace) {
        _opening = null;
        Error.throwWithStackTrace(error, trace);
      });

  Future<_NativeServices> _open() async {
    final sync = Sync.foreground(
      documentsDirectory: await _documentsDirectory(),
      catalog: _catalog,
      reservedAddresses: _reserved,
      freezes: _freezes,
      inputReservations: _inputReservations,
      fundingReservations: _fundingReservations,
      connections: _connections,
    );
    StreamSubscription<WalletRevisionState>? subscription;
    try {
      subscription = sync.changes.watch().listen(_changes.add);
      // Inject a failure after acquiring resources to verify cleanup in tests.
      _onStoresOpened?.call(sync.stores);
      return _NativeServices(sync, subscription);
    } catch (_) {
      try {
        await subscription?.cancel();
      } finally {
        await sync.close();
      }
      rethrow;
    }
  }

  Future<void> _initialize() => _initialization ??= _initializeSafely();

  Future<void> _initializeSafely() async {
    try {
      await _provision();
      _initializationFailure = null;
    } catch (error) {
      _initialization = null;
      if (_initializationFailure != error.runtimeType) {
        _initializationFailure = error.runtimeType;
        log.warning(
          'Native wallet initialization unavailable category=${error is WalletSnapshotException ? error.failure.logCode : 'storage'}',
        );
      }
      rethrow;
    }
  }

  /// Readers remain usable when a global catalog pass fails, provided their
  /// own catalog entry and native revision are available.
  Future<void> _initializeBestEffort() async {
    try {
      await _initialize();
    } on Exception {
      // The individual read or write still performs its own admission checks.
    }
  }

  /// Explicit provisioning retry; ordinary readers never trigger this pass.
  Future<void> _resumeProvisioning() async {
    try {
      await _initialize();
    } on Exception {
      // Explicit retry still retries a failed first opening.
    }
    _initialization = null;
    await _initialize();
  }

  Future<void> _provision() async {
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
            _value(await _deleteCatalogEntry(descriptor.key));
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
        if (result case Err(failure: SyncNeedsRepairFailure())) {
          result = await services.writer.repair(
            descriptor.key,
            expectedGeneration: state?.stamp.generation ?? 0,
          );
          if (result is Ok) {
            final synced = await _sync.execute(descriptor);
            if (synced case Err(:final failure)) {
              _unavailable[descriptor.key] = failure;
            }
            await _refresh(descriptor.key);
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
            : const SyncStorageFailure();
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
    Err(failure: SyncNotFoundFailure()) => null,
    Err(:final failure) => throw WalletSnapshotException(failure),
  };

  Future<void> _prepareCreate(WalletKey key) async {
    final services = await _services;
    final state = await _state(services, key);
    if (state != null && state.lifecycle == WalletLifecycle.deleted) {
      _value(
        await services.writer.prepareReimport(
          key,
          expectedGeneration: state.stamp.generation,
        ),
      );
    }
  }

  Future<void> _create(WalletKey key) async {
    final services = await _services;
    final state = await _state(services, key);
    _value(
      await services.writer.create(
        key,
        expectedGeneration: state?.stamp.generation ?? 0,
      ),
    );
    _unavailable.remove(key);
  }

  Future<void> _delete(WalletKey key) async {
    final services = await _services;
    final state = await _state(services, key);
    _value(
      await services.writer.delete(
        key,
        expectedGeneration: state?.stamp.generation ?? 0,
      ),
    );
    _unavailable.remove(key);
  }

  Future<({String address, int index})> _receive(
    WalletKey key, {
    bool advance = false,
  }) async {
    await _initializeBestEffort();

    final services = await _services;
    final state = await _state(services, key);
    final issued = _value(
      await services.writer.receive(
        key,
        expectedGeneration: state?.stamp.generation ?? 0,
        advance: advance,
      ),
    );
    return (address: issued.address, index: issued.index);
  }

  Future<int?> _issuedReceiveIndex(WalletKey key) async {
    final state = await _state(await _services, key);
    if (state?.lifecycle == WalletLifecycle.deleted) {
      throw const WalletSnapshotException(SyncNotFoundFailure());
    }
    return state?.issuedReceiveIndex;
  }

  Future<BitcoinSpendGate> get _spendGate async =>
      (await _services).stores.spendGate;

  /// Returns a handle for an exact network and generation.
  Future<sync.Wallet> _wallet(WalletKey key) async {
    await _initializeBestEffort();
    // A stale native generation is insufficient: the current catalog must
    // still contain this exact identity and network.
    _value(await _catalog.find(key));
    final failure = _unavailable[key];
    if (failure != null) throw WalletSnapshotException(failure);
    return _value(await (await _services).sync.wallet(key));
  }

  /// The Bitcoin guard's verdict, asked now under the writer lock.
  Future<BitcoinSpendStatus> _spendStatus(
    WalletKey key, {
    String? replacing,
  }) async {
    try {
      return switch (await (await _wallet(key)).tx
          .check(replacing: replacing)) {
        Ok(:final value) => value,
        Err(failure: SyncBusyFailure()) => BitcoinSpendStatus.busy,
        Err() => BitcoinSpendStatus.unavailable,
      };
    } on Exception {
      return BitcoinSpendStatus.unavailable;
    }
  }

  /// Broadcasts [transaction] for [key] through `wallet.tx`, which
  /// checks its generation and inputs again under the guard. [built] carries
  /// the generation it was built at; without it, the current one is used.
  /// A wallet of another [network] than the one expected is refused before
  /// any admission or server.
  Future<Result<SpendReceipt, SyncFailure>> broadcast(
    WalletKey key,
    SignedTransaction transaction, {
    required Network network,
    UnsignedSpend? built,
    SpendOwner? owner,
    String? replacing,
  }) async {
    final sync.Wallet handle;
    try {
      handle = await _wallet(key);
    } on WalletSnapshotException catch (error) {
      return Err(error.failure);
    } on Exception {
      return const Err(SyncStorageFailure());
    }
    if (built != null && built.key != handle.key) {
      return const Err(SyncNotFoundFailure());
    }
    // Never admitted nor sent on a network the caller did not expect.
    if (handle.key.network != network) {
      return const Err(SyncSpendBlockedFailure(BitcoinSpendStatus.unavailable));
    }
    return handle.tx.broadcast(
      built?.signed(transaction) ??
          handle.tx.signed(transaction, owner: owner, replacing: replacing),
    );
  }

  /// Called before a Payjoin terminal transition releases owned-input guards.
  Future<bool> _protectObservedSpend(WalletKey key, String txid) async {
    try {
      if (key.network is! BitcoinNetwork) return false;
      _value(await _catalog.find(key));
      final admission = await (await _spendGate).acquire(key, handoff: true);
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

  /// A wallet whose values are loaded at its latest committed revision, from
  /// local stores only. Throws [WalletSnapshotException] with the failure.
  Future<sync.Wallet> _loadWallet(WalletKey key) async {
    await _initializeBestEffort();
    final failure = _unavailable[key];
    if (failure != null) throw WalletSnapshotException(failure);
    final wallet = _value(await (await _services).sync.wallet(key));
    _value(await wallet.load());
    return wallet;
  }

  /// The foreground [Sync], for freezes. Opens it on first use.
  Future<Sync> _foreground() async => (await _services).sync;

  /// Called after every worker outcome, including interrupted/failed writes.
  Future<void> _refresh(WalletKey key, {bool catalogChanged = false}) async {
    final services = await _services;
    final state = await services.stores.revisions.read(key);
    if (state case Err(:final failure) when failure is! SyncNotFoundFailure) {
      throw WalletSnapshotException(failure);
    }
    if (state case Ok(:final value) when catalogChanged) {
      _changes.add(value);
    }
    if (state case Ok(value: final value)
        when value.lifecycle == WalletLifecycle.active) {
      _unavailable.remove(key);
    }
  }

  Future<void> _catalogDeleted(WalletKey key) async {
    await _refresh(key, catalogChanged: true);
  }

  Future<void> _refreshAll() async {
    final descriptors = _value(await _catalog.list());
    for (final descriptor in descriptors) {
      await _refresh(descriptor.key);
    }
  }

  Future<void> _repair(WalletKey key) async {
    final services = await _services;
    final state = await _state(services, key);
    _value(
      await services.writer.repair(
        key,
        expectedGeneration: state?.stamp.generation ?? 0,
      ),
    );
  }

  Future<void> _close() async {
    final opening = _opening;
    if (opening != null) {
      final services = await opening;
      try {
        await services.subscription.cancel();
      } finally {
        await services.sync.close();
      }
    }
    await _changes.close();
  }

  static T _value<T>(Result<T, SyncFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw WalletSnapshotException(failure),
  };
}

final class _NativeServices {
  final Sync sync;
  final StreamSubscription<WalletRevisionState> subscription;
  _NativeServices(this.sync, this.subscription);

  ForegroundStores get stores => sync.stores;

  WalletWriterRepository get writer => stores.writer;
}
