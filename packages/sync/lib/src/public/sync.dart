import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../data/datasources/revision_store_datasource.dart';
import '../data/freeze_authority.dart';
import '../data/native_store_paths.dart';
import '../data/read/native_frame_source.dart';
import '../data/wallet_projections.dart';
import '../data/datasources/spend_gate_store_datasource.dart'
    show BitcoinSpendGateUnavailable;
import '../data/write/sync/electrum_sync.dart';
import '../data/write/writer_stores.dart' as stores_;
import '../data/write/writer_stores.dart' show ExistingStores, ForegroundStores;
import '../domain/coin_freezes.dart';
import '../domain/observed.dart';
import '../domain/ports/legacy_freeze_source_port.dart';
import '../domain/ports/reserved_address_port.dart';
import '../domain/ports/wallet_catalog_port.dart';
import '../domain/ports/wallet_connection_port.dart';
import '../domain/public_wallet_descriptor.dart';
import '../domain/sync_completion.dart';
import '../domain/sync_failure.dart';
import '../domain/sync_reason.dart';
import '../domain/wallet_key.dart';
import '../domain/wallet_revision.dart';
import '../domain/wallet_values.dart';

/// The foreground owner of native wallet state in this isolate.
///
/// [Sync.wallet] hands out [Wallet] handles: a key and a captured generation,
/// never a native object. Values are read through `now`/`watch()`; nothing
/// is loaded until [Wallet.load] or a revision change asks for it.
final class Sync {
  final ForegroundStores _stores;
  final WalletProjections _projections;
  final _Cell<bool> _recoveryPending;

  Sync._(this._stores, this._projections)
    : _recoveryPending = _Cell(_stores.recoveredMetadata);

  /// Opens or creates the package stores, quarantining unreadable revision
  /// metadata, before any sync pass can run. Throws when storage is unusable.
  ///
  /// Then starts the one-time import of [legacyFreezes] into the freeze
  /// store. Until it is witnessed, freeze changes and spends are refused and
  /// coins read unavailable; each later use retries it.
  static Sync openForeground({
    required String documentsDirectory,
    required WalletCatalogPort catalog,
    required ReservedAddressPort reservedAddresses,
    required LegacyFreezeSourcePort legacyFreezes,
  }) {
    final stores = stores_.openForeground(
      documentsDirectory: documentsDirectory,
      catalog: catalog,
      reservedAddresses: reservedAddresses,
      legacyFreezes: legacyFreezes,
    );
    stores.freezes.demand();
    return Sync._(
      stores,
      WalletProjections(
        revisions: stores.revisions,
        changes: stores.changes,
        source: NativeFrameSource(stores.reader, catalog),
        freezes: stores.freezes,
      ),
    );
  }

  /// Background access: refresh existing wallets, nothing else. Throws
  /// [RevisionStoreUnavailable] when the foreground has not created the
  /// stores at the current version, or while quarantined metadata awaits
  /// adoption. Never creates, migrates or adopts.
  static HeadlessSync openExisting({
    required String documentsDirectory,
    required WalletCatalogPort catalog,
    required WalletConnectionPort connections,
  }) {
    if (File(recoveryMarkerPath(documentsDirectory)).existsSync()) {
      throw const RevisionStoreUnavailable();
    }
    final stores = stores_.openExisting(documentsDirectory);
    return HeadlessSync._(
      stores,
      catalog,
      ElectrumSync(
        connections: connections,
        documentsDirectory: () async => documentsDirectory,
        readRevision: stores.revisions.read,
      ),
    );
  }

  /// A handle on [key]'s active generation, from revision metadata only.
  /// A handle obtained before a delete or re-import never follows it.
  @useResult
  Future<Result<Wallet, SyncFailure>> wallet(WalletKey key) async =>
      switch (await _projections.generation(key)) {
        Ok(value: final generation) => Ok(
          Wallet._(_projections, key, generation),
        ),
        Err(:final failure) => Err(failure),
      };

  /// Revision states this isolate commits or reads, for every wallet.
  SyncChanges get changes => SyncChanges._(this);

  /// Adoption after quarantined revision metadata.
  SyncRecovery get recovery => SyncRecovery._(this);

  /// Freezes by outpoint, for every wallet, including those of no known
  /// wallet (BIP329). [Wallet.coins] changes the same store.
  SyncCoins get coins => SyncCoins._(_projections.freezes);

  /// Publishes `closed` to every observer, then ends their streams.
  Future<void> close() async {
    try {
      await _projections.close();
      _recoveryPending.close();
    } finally {
      await _stores.close();
    }
  }

  @useResult
  Result<void, SyncFailure> _completeRecovery() {
    if (_projections.isClosed) return const Err(SyncClosedFailure());
    try {
      _stores.completeRecovery();
    } on BitcoinSpendGateUnavailable {
      return const Err(SyncStorageFailure());
    } on FileSystemException {
      return const Err(SyncStorageFailure());
    }
    _recoveryPending.set(false);
    return const Ok(null);
  }
}

/// Transitional: the writer, spend gate and borrowed reader the app still
/// uses until spends and lifecycle commands move onto [Wallet]. Exported by
/// `write.dart` only.
extension SyncForegroundStores on Sync {
  ForegroundStores get stores => _stores;
}

/// `sync.changes.watch()`.
extension type const SyncChanges._(Sync _sync) {
  /// Every state this isolate commits or reads. Re-read on resume: commits
  /// made by another isolate surface only when read here.
  Stream<WalletRevisionState> watch() => _sync._stores.changes;
}

/// `sync.recovery.pending` and `sync.recovery.complete()`.
extension type const SyncRecovery._(Sync _sync) {
  /// True while quarantined metadata awaits adoption: existing native stores
  /// only, and no Bitcoin spend is admitted.
  Observed<bool> get pending => _sync._recoveryPending;

  /// Invalidates every retained spend observation, then lifts the barrier.
  /// Call once every catalog wallet has an outcome.
  @useResult
  Result<void, SyncFailure> complete() => _sync._completeRecovery();
}

/// `sync.coins`: the freeze store, without a wallet.
extension type const SyncCoins._(FreezePolicy _freezes) {
  /// Every freeze with its attribution, for BIP329 export.
  @useResult
  Future<Result<List<FrozenOutpoint>, SyncFailure>> listFrozen() =>
      _freezes.read();

  /// Freezes [outpoint] for every wallet, attributed to [origin] as given:
  /// empty for an import without a known wallet. Wallets use
  /// `wallet.coins.freeze`.
  @useResult
  Future<Result<PolicyRevision, SyncFailure>> freeze(
    Outpoint outpoint, {
    required String origin,
  }) => _freezes.freeze([FrozenOutpoint(outpoint, origin: origin)]);

  /// Removes every attribution of [outpoint].
  @useResult
  Future<Result<PolicyRevision, SyncFailure>> unfreeze(Outpoint outpoint) =>
      _freezes.unfreeze([outpoint]);

  /// After [SyncFreezeStoreLostFailure]: checks the store, its marker and its
  /// witness again. Never recreates the store nor imports the app's table
  /// again, so it succeeds only if the store is whole.
  @useResult
  Future<Result<void, SyncFailure>> recover() => _freezes.recover();
}

/// A wallet of one key and generation. Holds no native object.
///
/// Reads are [Observed] values: `now` is the last published value of this
/// isolate, `watch()` emits it then each change. They never trigger IO.
/// Commands are awaited and return a [Result].
///
/// ⚠️ A protocol decision (Payjoin input ownership, coin selection, a cold
/// resume) uses [ownership] or [unspent], never a `now`: those load the
/// exact committed revision and refuse an older one.
final class Wallet {
  final WalletProjections _projections;
  final WalletKey key;
  final int generation;

  Wallet._(this._projections, this.key, this.generation);

  Observed<WalletBalances> get balances =>
      _projections.observe(key, generation, (frame) => frame.balances);

  /// Coins with their frozen state; freeze and unfreeze them.
  WalletCoinsGroup get coins => WalletCoinsGroup._(this);

  Observed<WalletTransactions> get transactions =>
      _projections.observe(key, generation, (frame) => frame.transactions);

  WalletAddressGroup get addresses => WalletAddressGroup._(this);

  /// Loads every value at the latest committed revision, from local stores
  /// only (no network; see sync for that), and returns the revision
  /// published. A busy writer can leave it stale: the values then say so.
  @useResult
  Future<Result<WalletRevision, SyncFailure>> load() =>
      _projections.load(key, generation);

  /// The exact ownership index at the latest committed revision: scripts and
  /// outpoints, spent ones included. Busy when only an older revision or a
  /// cache is available, as while a writer holds the wallet; unsupported for
  /// Liquid.
  @useResult
  Future<Result<OwnershipIndex, SyncFailure>> ownership() async =>
      switch (await _projections.exact(key, generation)) {
        Ok(value: WalletFrame(ownership: final OwnershipIndex index)) => Ok(
          index,
        ),
        Ok() => const Err(SyncUnsupportedNetworkFailure()),
        Err(:final failure) => Err(failure),
      };

  /// The unspent coins at the latest committed revision, with the freezes
  /// read from the store. Busy when only an older revision or a cache is
  /// available.
  @useResult
  Future<Result<CoinList, SyncFailure>> unspent() async {
    final exact = await _projections.exact(key, generation);
    if (exact case Err(:final failure)) return Err(failure);
    final frozen = await _projections.freezes.forbiddenInputs();
    if (frozen case Err(:final failure)) return Err(failure);
    return Ok(
      (exact as Ok<WalletFrame, SyncFailure>).value.coins.withFrozen(
        (frozen as Ok<Set<Outpoint>, SyncFailure>).value,
      ),
    );
  }

  /// Refuses a handle a delete or a re-import has ended.
  Future<Result<void, SyncFailure>> _current() async =>
      switch (await _projections.generation(key)) {
        Ok(:final value) when value == generation => const Ok(null),
        Ok() => const Err(SyncNotFoundFailure()),
        Err(:final failure) => Err(failure),
      };
}

/// `wallet.coins`: the coins [Observed] with their frozen state, and the
/// freeze commands of this wallet.
extension type const WalletCoinsGroup._(Wallet _wallet) {
  Observed<WalletCoins> get _coins =>
      _wallet._projections.coins(_wallet.key, _wallet.generation);

  /// The last published coins. Unavailable while the freezes are unknown:
  /// a coin never reads as unfrozen by default.
  WalletCoins get now => _coins.now;

  Stream<WalletCoins> watch() => _coins.watch();

  /// Freezes [outpoint] for every wallet, attributed to this one. Returns
  /// once committed; the coins are then republished.
  @useResult
  Future<Result<PolicyRevision, SyncFailure>> freeze(Outpoint outpoint) async {
    if (await _wallet._current() case Err(:final failure)) return Err(failure);
    return _wallet._projections.freezes.freeze([
      FrozenOutpoint(outpoint, origin: _wallet.key.id),
    ]);
  }

  /// Removes every attribution of [outpoint], whichever wallet or import
  /// froze it. Returns once committed.
  @useResult
  Future<Result<PolicyRevision, SyncFailure>> unfreeze(
    Outpoint outpoint,
  ) async {
    if (await _wallet._current() case Err(:final failure)) return Err(failure);
    return _wallet._projections.freezes.unfreeze([outpoint]);
  }
}

/// `wallet.addresses`.
extension type const WalletAddressGroup._(Wallet _wallet) {
  /// The receive and change indexes reached, with their addresses.
  Observed<WalletAddresses> get current => _wallet._projections.observe(
    _wallet.key,
    _wallet.generation,
    (frame) => frame.addresses,
  );

  /// The address at [index], derived without revealing anything. Beyond the
  /// indexes reached it is derived on request, then published.
  Observed<WalletAddressAt> at(
    int index, {
    Keychain keychain = Keychain.external,
  }) => _wallet._projections.addressAt(
    _wallet.key,
    _wallet.generation,
    index,
    keychain,
  );

  /// Ownership for display. Protocol decisions use [Wallet.ownership].
  WalletOwnsGroup get owns => WalletOwnsGroup._(_wallet);
}

/// `wallet.addresses.owns`.
extension type const WalletOwnsGroup._(Wallet _wallet) {
  Observed<WalletOwnership> script(Uint8List script) => _wallet._projections
      .owns(_wallet.key, _wallet.generation, script: script);

  Observed<WalletOwnership> outpoint(Outpoint outpoint) => _wallet._projections
      .owns(_wallet.key, _wallet.generation, outpoint: outpoint);
}

/// What background code may do: refresh an existing wallet, then close.
final class HeadlessSync {
  final ExistingStores _stores;
  final WalletCatalogPort _catalog;
  final ElectrumSync _engine;
  bool _closed = false;

  HeadlessSync._(this._stores, this._catalog, this._engine);

  /// Synchronizes an existing store in a worker. Never creates, adopts or
  /// repairs: those wait for the foreground. Incoming payment ids are
  /// collected only with [collectIncoming].
  @useResult
  Future<Result<SyncCompletion, SyncFailure>> refresh(
    WalletKey key, {
    bool collectIncoming = false,
  }) async {
    if (_closed) return const Err(SyncClosedFailure());
    final descriptor = await _catalog.find(key);
    if (descriptor case Err(:final failure)) return Err(failure);
    return _engine.execute(
      (descriptor as Ok<PublicWalletDescriptor, SyncFailure>).value,
      headless: true,
      reason: SyncReason.background,
      allowInitialScan: false,
      collectIncoming: collectIncoming,
    );
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _stores.close();
  }
}

final class _Cell<T> implements Observed<T> {
  T _value;
  final _changes = StreamController<T>.broadcast(sync: true);

  _Cell(this._value);

  void set(T value) {
    if (value == _value) return;
    _value = value;
    _changes.add(value);
  }

  void close() => unawaited(_changes.close());

  @override
  T get now => _value;

  @override
  Stream<T> watch() {
    late final StreamController<T> controller;
    StreamSubscription<T>? subscription;
    controller = StreamController<T>(
      onListen: () {
        controller.add(_value);
        if (_changes.isClosed) {
          unawaited(controller.close());
          return;
        }
        subscription = _changes.stream.listen(
          controller.add,
          onDone: controller.close,
        );
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }
}

/// Package tests build handles over a fake frame source; not exported.
@visibleForTesting
Wallet walletOver(
  WalletProjections projections,
  WalletKey key,
  int generation,
) => Wallet._(projections, key, generation);
