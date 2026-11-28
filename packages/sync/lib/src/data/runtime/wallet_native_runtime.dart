import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/storage.dart'
    show WalletCatalogueSignal, WalletCatalogueStamp;

import '../../../inventory.dart';
import '../../../sync.dart' hide Wallet;
import '../../../sync.dart' as sync show Wallet;
import '../../../write.dart';
import '../freeze_authority.dart';
import '../input_reservations.dart';
import '../../public/sync.dart' show SyncForegroundStores;
import 'foreground_lifetime.dart';

typedef _RevisionMount = ({Sync sync, WalletCatalogPort catalog});

/// The committed environment and its transition epoch. Supply no context
/// during transitions or while the committed environment is unknown.
typedef BalanceEnvironment = ({NetworkEnv environment, int epoch});

/// A per-key observation admitted at the origin, not a permission to open.
final class RetainedBalanceDemand {
  final WalletKey key;
  final WalletCatalogueStamp catalogue;
  final BalanceEnvironment environment;
  final WalletNativeRuntime _runtime;
  final BalanceEnvironment? Function() _readEnvironment;

  const RetainedBalanceDemand._(
    this.key,
    this.catalogue,
    this.environment,
    this._runtime,
    this._readEnvironment,
  );

  /// Recheck after awaiting a receipt and before using it.
  bool get isCurrent =>
      _runtime._closing == null &&
      _readEnvironment() == environment &&
      _runtime._walletCatalogue?.isCurrent(catalogue) == true;
}

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
  _NativeServices? _openedServices;
  Future<void>? _initialization;
  bool _initialized = false;
  Type? _initializationFailure;
  final void Function(ForegroundStores)? _onStoresOpened;
  final FreezeStorePort _freezes;
  final WalletConnectionPort _connections;
  final BroadcastObservationFollowUp? _broadcastObservation;
  ForegroundLifetime<_RevisionMount>? _revisionLifetime;
  Future<void> Function()? _afterRevisionRead;
  final _scopedRequests = <Future<void>>{};
  final _balanceChanges = StreamController<void>.broadcast();
  final Future<void> Function()? _beforeBalanceHydration;
  final Future<void> Function()? _beforeBalancePublication;
  Future<Result<void, SyncFailure>>? _closing;

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
    this._broadcastObservation,
    @visibleForTesting this._onStoresOpened,
    @visibleForTesting this._beforeBalanceHydration,
    @visibleForTesting this._beforeBalancePublication,
  });

  /// Opt-in proof of the first scoped slice, not an app composition path.
  /// The tracked owner can also serve as the eventual locator disposer.
  @visibleForTesting
  static ({WalletNativeRuntime runtime, LifecycleHandle owner})
  foregroundRevisionProof({
    required RuntimeAdmission admission,
    required SecretsWalletCatalog catalog,
    required ReservedAddressPort reserved,
    required InputReservationPort inputReservations,
    required ElectrumSync sync,
    required Future<String> Function() documentsDirectory,
    required FreezeStorePort freezes,
    required WalletConnectionPort connections,
    void Function(ForegroundStores)? onStoresOpened,
    Future<void> Function()? afterRevisionRead,
    Future<Result<void, SyncFailure>> Function()? afterStoresClosed,
  }) {
    final session = catalog.foregroundSession;
    if (session == null) throw ArgumentError('Expected a foreground catalog');
    final runtime = WalletNativeRuntime.open(
      catalog: const _ClosedCatalog(),
      reserved: reserved,
      inputReservations: inputReservations,
      deleteCatalogEntry: (_) async => const Err(SyncClosedFailure()),
      sync: sync,
      documentsDirectory: documentsDirectory,
      freezes: freezes,
      connections: connections,
    );
    final owner = admission.track(() async {
      if (await runtime.close() case Err()) {
        throw const LifecycleException('native_runtime_close_unconfirmed');
      }
    });
    runtime._afterRevisionRead = afterRevisionRead;
    late final ForegroundLifetime<_RevisionMount> lifetime;
    lifetime = ForegroundLifetime(
      session,
      open: (grant) async {
        final bound = catalog.captureForeground(grant);
        if (bound == null) return const Err(SyncClosedFailure());
        final directory = await runtime._documentsDirectory();
        if (!lifetime.isCurrent(grant)) return const Err(SyncClosedFailure());
        final mounted = runtime._openSync(directory, bound);
        try {
          onStoresOpened?.call(mounted.stores);
        } catch (_) {
          await mounted.close();
          rethrow;
        }
        return Ok((sync: mounted, catalog: bound));
      },
      close: (mounted) async {
        await mounted.sync.close();
        return afterStoresClosed == null ? const Ok(null) : afterStoresClosed();
      },
    );
    runtime._revisionLifetime = lifetime;
    return (runtime: runtime, owner: owner);
  }

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

  /// The spend readiness of [walletId] as the catalog resolves it. A wallet
  /// the catalog cannot resolve, or whose state is unreadable, is never ready.
  Future<BitcoinSpendStatus> spendStatusOf(String walletId) async {
    final WalletKey key;
    switch (await _catalog.list()) {
      case Ok(:final value):
        final found = value
            .where((descriptor) => descriptor.key.id == walletId)
            .firstOrNull;
        if (found == null) return BitcoinSpendStatus.unavailable;
        key = found.key;
      case Err():
        return BitcoinSpendStatus.unavailable;
    }
    return switch (await spendStatus(key)) {
      Ok(:final value) => value,
      Err() => BitcoinSpendStatus.unavailable,
    };
  }

  Future<Result<bool, SyncFailure>> protectObservedSpend(
    WalletKey key,
    String txid,
  ) => _result(() => _protectObservedSpend(key, txid));
  Future<Result<sync.Wallet, SyncFailure>> loadWallet(WalletKey key) {
    final signal = _walletCatalogue;
    final stamp = signal?.capture();
    if (signal != null && stamp == null) {
      return Future.value(const Err(SyncClosedFailure()));
    }
    return _result(() => _loadWallet(key, stamp));
  }

  WalletCatalogueSignal? get _walletCatalogue => switch (_catalog) {
    final SecretsWalletCatalog catalog => catalog.walletCatalogue,
    _ => null,
  };

  /// Capture synchronously before queueing or waiting. [readEnvironment] must
  /// be a synchronous, side-effect-free snapshot; advance its epoch even if a
  /// transition later returns to the same environment. Pass [catalogue] when
  /// the caller already captured it before selecting the key: an expired stamp
  /// is refused, never replaced with the current one.
  RetainedBalanceDemand? captureBalanceDemand(
    WalletKey key,
    BalanceEnvironment? Function() readEnvironment, {
    WalletCatalogueStamp? catalogue,
  }) {
    if (_closing != null) return null;
    final stamp = catalogue ?? _walletCatalogue?.capture();
    final environment = readEnvironment();
    if (stamp == null ||
        environment == null ||
        environment.environment != key.network.env) {
      return null;
    }
    final demand = RetainedBalanceDemand._(
      key,
      stamp,
      environment,
      this,
      readEnvironment,
    );
    return demand.isCurrent ? demand : null;
  }

  /// Wake-up only: no balance, key, or synthetic native revision. Recheck
  /// admission when handling an event delivered after an invalidation.
  Stream<void> get retainedBalanceChanges => _balanceChanges.stream;

  /// Explicitly maps one local balance, even at an unchanged native revision.
  /// Never waits for initialization, opens an owner, or retries provisioning.
  @useResult
  Future<Result<WalletRevision, SyncFailure>> demandRetainedBalance(
    RetainedBalanceDemand demand,
  ) async {
    if (!identical(demand._runtime, this) || !demand.isCurrent) {
      return const Err(SyncClosedFailure());
    }
    final owner = _openedServices;
    final initialization = _initialization;
    if (owner == null || initialization == null || !_initialized) {
      return const Err(SyncBusyFailure());
    }
    final key = demand.key;
    if (_unavailable[key] case final failure?) return Err(failure);
    final catalog = _catalog;
    final bound = catalog is SecretsWalletCatalog
        ? catalog.bindWalletCatalogue(demand.catalogue)
        : null;
    if (bound == null) return const Err(SyncClosedFailure());

    final settled = Completer<void>();
    _scopedRequests.add(settled.future);
    bool current() =>
        demand.isCurrent &&
        identical(owner, _openedServices) &&
        identical(initialization, _initialization) &&
        _initialized &&
        !_unavailable.containsKey(key);
    try {
      final result = await owner.sync.retainBalance(
        key,
        demand.catalogue,
        bound,
        isCurrent: current,
        beforeHydration: _beforeBalanceHydration,
        beforePublication: _beforeBalancePublication,
      );
      if (!current()) return const Err(SyncClosedFailure());
      if (result case Ok(value: final stamp)) {
        final retained = readRetainedBalance(demand.catalogue, stamp);
        if (!current()) return const Err(SyncClosedFailure());
        if (retained case Err(:final failure)) return Err(failure);
        _balanceChanges.add(null);
      }
      return result;
    } finally {
      _scopedRequests.remove(settled.future);
      settled.complete();
    }
  }

  /// A balance already admitted under [catalogue] and exactly [stamp].
  /// Never opens the runtime or a native wallet, and publishes no revisions.
  @useResult
  Result<BigInt, SyncFailure> readRetainedBalance(
    WalletCatalogueStamp catalogue,
    WalletRevision stamp,
  ) {
    final signal = _walletCatalogue;
    final owner = _openedServices;
    if (_closing != null || signal?.isCurrent(catalogue) != true) {
      return const Err(SyncClosedFailure());
    }
    if (owner == null) return const Err(SyncNotFoundFailure());
    final total = owner.sync.retainedTotal(catalogue, stamp);
    if (total == null) return const Err(SyncNotFoundFailure());
    return switch (owner.stores.retainedRevision(stamp.key)) {
      Ok(value: final state)
          when state.stamp == stamp &&
              signal?.isCurrent(catalogue) == true &&
              _closing == null =>
        Ok(total),
      Ok() => const Err(SyncNotFoundFailure()),
      Err(:final failure) => Err(failure),
    };
  }

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
  Future<Result<void, SyncFailure>> close() {
    if (_closing case final closing?) return closing;
    final closed = Completer<Result<void, SyncFailure>>();
    _closing = closed.future;
    // A paused observer must not prevent closing the native owner.
    unawaited(_balanceChanges.close());
    closed.complete(switch (_revisionLifetime) {
      final lifetime? => _closeRevisionProof(lifetime),
      null => _result(_close),
    });
    return closed.future;
  }

  Future<Result<void, SyncFailure>> _closeRevisionProof(
    ForegroundLifetime<_RevisionMount> lifetime,
  ) async {
    final closed = await lifetime.stop();
    await _changes.close();
    return closed;
  }

  Stream<WalletRevisionState> get changes => _changes.stream;

  /// Runs the durable callback under the normal Bitcoin spend admission.
  /// Only the admitted revision is lent; the lease closes before this returns.
  /// The callback must not reenter Sync or close this runtime, sign, do
  /// network work, or detach work. Its exceptions propagate unchanged.
  @useResult
  Future<Result<void, SyncFailure>> withBitcoinRevisionAdmission(
    WalletKey key,
    Future<void> Function(WalletRevision) use,
  ) => _withScopedServices((services) async {
    final admission = await services.stores.spendGate.acquire(key);
    if (admission is! BitcoinSpendAdmission) {
      return const Err(SyncBusyFailure());
    }
    try {
      await use(admission.revision);
      return const Ok(null);
    } finally {
      admission.close();
    }
  });

  /// Combined ordinary and funding reservations, without owner metadata.
  /// A typed reservation read failure means unknown, not an empty snapshot.
  @useResult
  Future<Result<Set<Outpoint>?, SyncFailure>>
  readReservedOutpointsForDisplay() => _withScopedServices((services) async {
    return switch (await services.stores.inputReservations.reservations()) {
      Ok(:final value) => Ok(Set.unmodifiable(value.map((r) => r.outpoint))),
      Err() => const Ok(null),
    };
  });

  /// Reads the effective freezes now, across all origins, for spend preflight.
  /// A failed read is not evidence that any input is spendable.
  @useResult
  Future<Result<Set<Outpoint>, SyncFailure>> readFrozenOutpoints() =>
      _withScopedServices(
        (services) => services.stores.freezes.forbiddenInputs(),
      );

  /// Lists every stored attribution for BIP329 export.
  @useResult
  Future<Result<List<FrozenOutpoint>, SyncFailure>> listAttributedFreezes() =>
      _withScopedServices((services) => services.stores.freezes.read());

  /// Freezes outputs using one wallet generation, checked on each write.
  @useResult
  Future<Result<void, SyncFailure>> freezeWalletOutpoints(
    WalletKey key,
    List<Outpoint> outpoints,
  ) {
    final inputs = List.of(outpoints);
    return _withScopedServices((services) async {
      final lookup = await services.sync.wallet(key);
      if (lookup case Err(:final failure)) return Err(failure);
      final wallet = _value(lookup);
      for (final input in inputs) {
        if (await wallet.coins.freeze(input) case Err(:final failure)) {
          return Err(failure);
        }
      }
      return const Ok(null);
    });
  }

  /// Applies already attributed rows in order; earlier commits survive failure.
  @useResult
  Future<Result<void, SyncFailure>> freezeAttributedOutpoints(
    List<FrozenOutpoint> rows,
  ) {
    final inputs = List.of(rows);
    return _withScopedServices((services) async {
      for (final row in inputs) {
        if (await services.stores.freezes.freeze([row]) case Err(
          :final failure,
        )) {
          return Err(failure);
        }
      }
      return const Ok(null);
    });
  }

  /// Removes every attribution of each outpoint, in order.
  @useResult
  Future<Result<void, SyncFailure>> unfreezeOutpoints(
    List<Outpoint> outpoints,
  ) {
    final inputs = List.of(outpoints);
    return _withScopedServices((services) async {
      for (final input in inputs) {
        if (await services.stores.freezes.unfreeze([input]) case Err(
          :final failure,
        )) {
          return Err(failure);
        }
      }
      return const Ok(null);
    });
  }

  Future<Result<T, SyncFailure>> _withScopedServices<T>(
    Future<Result<T, SyncFailure>> Function(_NativeServices) operation,
  ) async {
    if (_closing != null || _revisionLifetime != null) {
      return const Err(SyncClosedFailure());
    }
    final settled = Completer<void>();
    _scopedRequests.add(settled.future);
    try {
      // Map opening failures only, not errors from the operation or callback.
      return switch (await _result(() => _services)) {
        Ok(:final value) => await operation(value),
        Err(:final failure) => Err(failure),
      };
    } finally {
      _scopedRequests.remove(settled.future);
      settled.complete();
    }
  }

  /// Checks the current protocol reservations for selected ordinary inputs.
  /// An empty selection checks that the reservation authorities are readable.
  /// This is a preview check only; the writer rechecks at the point of use.
  @useResult
  Future<Result<void, SyncFailure>> checkUnreservedInputs(
    Set<Outpoint> selected,
  ) async {
    if (_revisionLifetime != null) return const Err(SyncClosedFailure());
    final inputs = Set.of(selected);
    final reservations = CombinedInputReservations(
      _inputReservations,
      _fundingReservations,
    );
    switch (await reservations.reservations()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final blocked = {
          for (final reservation in value)
            if (inputs.contains(reservation.outpoint)) reservation.outpoint,
        };
        return blocked.isEmpty
            ? const Ok(null)
            : Err(SyncProtectedInputsFailure(reserved: blocked));
    }
  }

  /// An imported transaction has no wallet generation. It still goes
  /// through the same global freeze queue and authorized connection policy.
  @useResult
  Future<Result<String, SyncFailure>> broadcastImportedBitcoin(
    List<int> bytes, {
    required BitcoinNetwork network,
  }) async {
    final DecodedBitcoinTransaction transaction;
    try {
      transaction = decodeBitcoinTransaction(bytes);
    } on FormatException {
      return const Err(SyncInvalidTransactionFailure());
    }
    final opened = await _result(() async => (await _services).stores.freezes);
    final FreezeAuthority freezes;
    switch (opened) {
      case Ok(:final value):
        freezes = value;
      case Err(:final failure):
        return Err(failure);
    }
    return switch (await freezes.guard((frozen) async {
      final blocked = transaction.inputs.where(frozen.contains).toSet();
      if (blocked.isNotEmpty) {
        return Err<String, SyncFailure>(
          SyncProtectedInputsFailure(frozen: blocked),
        );
      }
      return broadcastBitcoinTransaction(
        transaction.bytes,
        network: network,
        connections: _connections,
      );
    })) {
      Ok(:final value) => value,
      Err(:final failure) => Err(failure),
    };
  }

  /// Broadcasts a spend that already carries its original wallet generation.
  /// Refreshes accepted broadcasts even if recording is not yet durable;
  /// only guarded Bitcoin broadcasts need follow-up observation.
  @useResult
  Future<Result<SpendReceipt, SyncFailure>> broadcastSigned(
    SignedSpend signed,
  ) async {
    switch (await wallet(signed.key)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final result = await value.tx.broadcast(signed);
        if (result case Ok(value: SpendReceipt(:final guarded))) {
          _broadcastObservation?.start(
            signed.key.id,
            guarded: guarded,
            pollImmediately: true,
          );
        }
        return result;
    }
  }

  /// Serializes local Payjoin reservation writes with ordinary Bitcoin
  /// broadcasts and user freezes. [persist] must not call Sync or the relay.
  @useResult
  Future<Result<void, SyncFailure>> reservePayjoinInputs(
    WalletKey key, {
    required Set<Outpoint> inputs,
    required String sessionId,
    required Future<void> Function() persist,
    int? expectedGeneration,
  }) async {
    final current = await wallet(key);
    return switch (current) {
      Err(:final failure) => Err(failure),
      Ok(:final value)
          when expectedGeneration == null ||
              value.generation == expectedGeneration =>
        (await _services).stores.spend.reservePayjoinInputs(
          key,
          value.generation,
          inputs,
          sessionId,
          persist,
        ),
      Ok() => const Err(SyncNotFoundFailure()),
    };
  }

  /// Privileged wallet composition must bind the exact same durable authority.
  bool usesFundingReservations(FundingReservationPort authority) =>
      identical(_fundingReservations, authority);

  Future<Result<WalletRevisionState, SyncFailure>> readRevision(
    WalletKey key,
  ) async {
    try {
      if (_revisionLifetime case final lifetime?) {
        final grant = lifetime.capture();
        if (grant == null) return const Err(SyncClosedFailure());
        return await lifetime.run(grant, (mounted) async {
          if (await mounted.catalog.find(key) case Err(:final failure)) {
            return Err(failure);
          }
          if (!lifetime.isCurrent(grant)) return const Err(SyncClosedFailure());
          final state = await mounted.sync.stores.revisions.read(key);
          await _afterRevisionRead?.call();
          return state;
        });
      }
      return await (await _services).stores.revisions.read(key);
    } on Exception {
      return const Err(SyncStorageFailure());
    }
  }

  Future<_NativeServices> get _services {
    if (_revisionLifetime != null) {
      throw const WalletSnapshotException(SyncClosedFailure());
    }
    return _opening ??= _open().catchError((Object error, StackTrace trace) {
      _opening = null;
      Error.throwWithStackTrace(error, trace);
    });
  }

  Sync _openSync(String directory, WalletCatalogPort catalog) =>
      Sync.foreground(
        documentsDirectory: directory,
        catalog: catalog,
        reservedAddresses: _reserved,
        freezes: _freezes,
        inputReservations: _inputReservations,
        fundingReservations: _fundingReservations,
        connections: _connections,
      );

  Future<_NativeServices> _open() async {
    final sync = _openSync(await _documentsDirectory(), _catalog);
    StreamSubscription<WalletRevisionState>? subscription;
    try {
      subscription = sync.changes.watch().listen(_changes.add);
      // Inject a failure after acquiring resources to verify cleanup in tests.
      _onStoresOpened?.call(sync.stores);
      final services = _NativeServices(sync, subscription);
      if (_closing == null) _openedServices = services;
      return services;
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
    _initialized = false;
    try {
      await _provision();
      _initializationFailure = null;
      _initialized = true;
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
  Future<sync.Wallet> _loadWallet(
    WalletKey key,
    WalletCatalogueStamp? catalogue,
  ) async {
    await _initializeBestEffort();
    final failure = _unavailable[key];
    if (failure != null) throw WalletSnapshotException(failure);
    final owner = (await _services).sync;
    final wallet = _value(await owner.wallet(key));
    _value(
      await (catalogue == null
          ? wallet.load()
          : owner.loadFromCatalogue(wallet, catalogue)),
    );
    return wallet;
  }

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
    _openedServices = null;
    await Future.wait(_scopedRequests);
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

final class _ClosedCatalog implements WalletCatalogPort {
  const _ClosedCatalog();

  @override
  Future<Result<List<PublicWalletDescriptor>, SyncFailure>> list() async =>
      const Err(SyncClosedFailure());

  @override
  Future<Result<PublicWalletDescriptor, SyncFailure>> find(
    WalletKey key,
  ) async => const Err(SyncClosedFailure());
}

final class _NativeServices {
  final Sync sync;
  final StreamSubscription<WalletRevisionState> subscription;
  _NativeServices(this.sync, this.subscription);

  ForegroundStores get stores => sync.stores;

  WalletWriterRepository get writer => stores.writer;
}
