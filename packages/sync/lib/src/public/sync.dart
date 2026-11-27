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
import '../data/write/spend/spend_writer.dart';
import '../data/write/writer_stores.dart' as stores_;
import '../data/write/writer_stores.dart' show ExistingStores, ForegroundStores;
import '../domain/bitcoin_spend.dart';
import '../domain/coin_freezes.dart';
import '../domain/observed.dart';
import '../domain/ports/freeze_store_port.dart';
import '../domain/ports/input_reservation_port.dart';
import '../domain/ports/funding_reservation_port.dart';
import '../domain/ports/reserved_address_port.dart';
import '../domain/ports/wallet_catalog_port.dart';
import '../domain/ports/wallet_connection_port.dart';
import '../domain/public_wallet_descriptor.dart';
import '../domain/spend.dart';
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
  Future<void>? _closing;

  Sync._(this._stores, this._projections)
    : _recoveryPending = _Cell(_stores.recoveredMetadata);

  /// Opens or creates the package stores, quarantining unreadable revision
  /// metadata, before any sync pass can run. Throws when storage is unusable.
  ///
  /// [freezes] is the app's freeze store: sync reads and changes it, and
  /// schedules a first read here. Coins read unavailable, never unfrozen,
  /// while it cannot answer. [inputReservations] is mandatory: spends check
  /// their inputs against both. Spends are broadcast through the servers
  /// [connections] selects.
  ///
  /// [fundingReservations] optionally enables atomic funding preparation. Its
  /// reads are always combined with [inputReservations] for every spend. A
  /// missing port refuses preparation; it never falls back to an unreserved
  /// build. Both providers must read directly, without reentering sync.
  static Sync foreground({
    required String documentsDirectory,
    required WalletCatalogPort catalog,
    required ReservedAddressPort reservedAddresses,
    required FreezeStorePort freezes,
    required InputReservationPort inputReservations,
    FundingReservationPort? fundingReservations,
    required WalletConnectionPort connections,
  }) {
    final stores = stores_.openForeground(
      documentsDirectory: documentsDirectory,
      catalog: catalog,
      reservedAddresses: reservedAddresses,
      freezes: freezes,
      inputReservations: inputReservations,
      fundingReservations: fundingReservations,
      connections: connections,
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
  static BackgroundSync background({
    required String documentsDirectory,
    required WalletCatalogPort catalog,
    required WalletConnectionPort connections,
  }) {
    if (File(recoveryMarkerPath(documentsDirectory)).existsSync()) {
      throw const RevisionStoreUnavailable();
    }
    final stores = stores_.openExisting(documentsDirectory);
    return BackgroundSync._(
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
          Wallet._(_projections, _stores.spend, key, generation),
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
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
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

/// Store access inside Sync, never exported by a consumer library.
@internal
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

/// `sync.coins`: the freezes, without a wallet.
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
  final WalletSpender _spender;
  final WalletKey key;
  final int generation;

  Wallet._(this._projections, this._spender, this.key, this.generation);

  /// Native transactions: build, bump, consolidate, then broadcast once
  /// signed.
  WalletTxGroup get tx => WalletTxGroup._(this);

  Observed<WalletBalances> get balances =>
      _projections.observe(key, generation, (frame) => frame.balances);

  /// Coins with their frozen state; freeze and unfreeze them.
  WalletCoinsGroup get coins => WalletCoinsGroup._(this);

  /// The wallet's transaction history.
  Observed<WalletTransactions> get history =>
      _projections.observe(key, generation, (frame) => frame.transactions);

  WalletAddressGroup get addresses => WalletAddressGroup._(this);

  /// Loads every value at the latest committed revision, from local stores
  /// only (no network; see sync for that), and returns the revision
  /// published. A busy writer can leave it stale: the values then say so.
  /// The freezes are read too when none are known yet, so coins are ready,
  /// or unavailable with the reason, once this returns.
  @useResult
  Future<Result<WalletRevision, SyncFailure>> load() async {
    final loaded = await _projections.load(key, generation);
    final freezes = _projections.freezes;
    if (freezes.snapshot == null) await freezes.read();
    return loaded;
  }

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

  /// Reads exact ownership, retrying briefly while the writer is busy.
  @useResult
  Future<Result<OwnershipIndex, SyncFailure>> readExactOwnership() =>
      _retryBusyRead(ownership);

  /// Reads exact unspent coins, retrying briefly while the writer is busy.
  @useResult
  Future<Result<CoinList, SyncFailure>> readExactUnspent() =>
      _retryBusyRead(unspent);

  static Future<Result<T, SyncFailure>> _retryBusyRead<T>(
    Future<Result<T, SyncFailure>> Function() query,
  ) async {
    for (var attempt = 1; ; attempt++) {
      final result = await query();
      if (result case Err(failure: SyncBusyFailure()) when attempt < 5) {
        await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
        continue;
      }
      return result;
    }
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

/// `wallet.tx`: commands of the single writer. Signing stays with the
/// caller, through `secrets` or a hardware signer, between build and
/// broadcast; no lock is held meanwhile.
///
/// ⚠️ Bitcoin only is guarded from admission to the receipt. Liquid has no
/// spend guard yet: its receipts say `guarded: false`, and only freezes are
/// checked at its broadcast.
extension type const WalletTxGroup._(Wallet _wallet) {
  /// Builds once on a native wallet opened for this command, after the
  /// guard admits the spend, and persists the change it reveals before
  /// handing the transaction out. Refuses an input that is frozen or
  /// reserved by another session ([SyncProtectedInputsFailure]).
  @useResult
  Future<Result<UnsignedSpend, SyncFailure>> build(SpendRequest request) =>
      _wallet._spender.build(_wallet.key, _wallet.generation, request);

  /// Builds unfinalised native-segwit funding and durably reserves its
  /// effective inputs before releasing the spend admission. Requires a
  /// non-null owner and a configured [FundingReservationPort]. [context]
  /// contains at most 4096 UTF-8 bytes of public recovery metadata.
  @useResult
  Future<Result<UnsignedSpend, SyncFailure>> prepareFunding(
    BitcoinSpendRequest request, {
    required String context,
  }) => _wallet._spender.prepareFunding(
    _wallet.key,
    _wallet.generation,
    request,
    context: context,
  );

  /// A BIP125 replacement, built only on an original whose own inputs'
  /// signatures verify. An input the builder adds faces every protection.
  @useResult
  Future<Result<UnsignedSpend, SyncFailure>> bump(BumpFeeRequest request) =>
      _wallet._spender.bump(_wallet.key, _wallet.generation, request);

  /// Liquid consolidation batches, each checked; empty when the wallet holds
  /// no more coins than the threshold.
  @useResult
  Future<Result<List<UnsignedSpend>, SyncFailure>> consolidate(
    ConsolidationRequest request,
  ) => _wallet._spender.consolidate(_wallet.key, _wallet.generation, request);

  /// Broadcasts [spend] after checking its generation and its inputs again,
  /// reservations included, under the guard. Bitcoin keeps the guard until
  /// the receipt; a receipt that is not durable keeps refusing spends in
  /// this process. A chain failure may leave the transaction relayed.
  @useResult
  Future<Result<SpendReceipt, SyncFailure>> broadcast(SignedSpend spend) =>
      _wallet._spender.broadcast(spend);

  /// A [SignedSpend] for a transaction signed in an earlier run, such as a
  /// Payjoin proposal or a saved payment, for this handle's generation.
  SignedSpend signed(
    SignedTransaction transaction, {
    SpendOwner? owner,
    String? replacing,
  }) => signedForGeneration(
    key: _wallet.key,
    generation: _wallet.generation,
    transaction: transaction,
    owner: owner,
    replacing: replacing,
  );

  /// The guard's last verdict, without IO. Scheduled on first demand and
  /// asked again after every revision of the wallet, and published by
  /// [check] and the spend commands. Never a permission: [build] and
  /// [broadcast] check again.
  Observed<WalletValue<BitcoinSpendStatus>> get readiness =>
      _wallet._spender.readiness(_wallet.key);

  /// Asks the guard now, under the writer lock, and publishes its verdict.
  @useResult
  Future<Result<BitcoinSpendStatus, SyncFailure>> check({String? replacing}) =>
      _wallet._spender.check(
        _wallet.key,
        _wallet.generation,
        replacing: replacing,
      );

  /// Whether the wallet's own inputs of its stored [txid] carry valid
  /// signatures: a replacement is only built on a valid one.
  @useResult
  Future<Result<SignatureCheck, SyncFailure>> originalSignatures(String txid) =>
      _wallet._spender.originalSignatures(
        _wallet.key,
        _wallet.generation,
        txid,
      );

  /// [psbt] with this wallet's derivations on what it owns, for a signer
  /// that learns its paths from the PSBT. Signs nothing.
  @useResult
  Future<Result<String, SyncFailure>> annotate(String psbt) =>
      _wallet._spender.annotate(_wallet.key, _wallet.generation, psbt);

  /// Policy-asset amount paid to this exact Liquid destination.
  @useResult
  Future<Result<BigInt, SyncFailure>> liquidAmountToAddress(
    String pset,
    String address,
  ) => _wallet._spender.liquidAmountToAddress(
    _wallet.key,
    _wallet.generation,
    pset,
    address,
  );

  /// What a Liquid [pset] does to this wallet's L-BTC, unblinded.
  @useResult
  Future<Result<LiquidPsetEffect, SyncFailure>> liquidEffect(String pset) =>
      _wallet._spender.liquidEffect(_wallet.key, _wallet.generation, pset);
}

/// `wallet.addresses`.
extension type const WalletAddressGroup._(Wallet _wallet) {
  /// The address book: the receive and change indexes reached, with their
  /// addresses.
  Observed<WalletAddresses> get book => _wallet._projections.observe(
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

  /// Address usage from the published frame and its coin freeze policy.
  ///
  /// A transaction paying the same address more than once counts once.
  /// Liquid outputs and coins use their confidential addresses.
  @useResult
  Result<Map<String, AddressUsage>, SyncFailure> usage() {
    final history = _wallet.history.now.latest;
    final addresses = book.now.latest;
    final coins = _wallet.coins.now.latest;
    if (history case Err(:final failure)) return Err(failure);
    if (addresses case Err(:final failure)) return Err(failure);
    final transactions =
        (history as Ok<ChainTransactionList, SyncFailure>).value;

    final counts = <String, int>{};
    final balances = <String, BigInt>{};
    for (final transaction in transactions) {
      if (transaction.feeSat == null) {
        return const Err(SyncNeedsRepairFailure());
      }
      final destinations = switch (transaction) {
        BitcoinTransaction(:final outputs) => {
          for (final output in outputs) ?output.address,
        },
        LiquidTransaction(:final outputs) => {
          for (final output in outputs) output.confidentialAddress,
        },
      };
      for (final address in destinations) {
        counts.update(address, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    if (coins case Err(:final failure)) return Err(failure);
    final unspent = (coins as Ok<CoinList, SyncFailure>).value;
    for (final coin in unspent) {
      final address = switch (coin) {
        BitcoinCoin(:final address) => address,
        LiquidCoin(:final confidentialAddress) => confidentialAddress,
      };
      if (address != null) {
        balances.update(
          address,
          (amount) => amount + coin.amountSat,
          ifAbsent: () => coin.amountSat,
        );
      }
    }
    return Ok(
      Map.unmodifiable({
        for (final address in {...counts.keys, ...balances.keys})
          address: (
            balanceSat: balances[address] ?? BigInt.zero,
            transactionCount: counts[address] ?? 0,
          ),
      }),
    );
  }

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

/// What background code may do: refresh an existing wallet, read the
/// revision this isolate last saw, and close. Nothing else: no wallet
/// handle, address, freeze, spend, creation, discovery or initial scan.
final class BackgroundSync {
  final ExistingStores _stores;
  final WalletCatalogPort _catalog;
  final ElectrumSync _engine;
  final _revisions = <WalletKey, WalletValue<WalletRevisionState>>{};
  late final StreamSubscription<WalletRevisionState> _changes;
  bool _closed = false;

  BackgroundSync._(this._stores, this._catalog, this._engine) {
    _changes = _stores.changes.listen(_seen);
  }

  /// Synchronizes an existing store in a worker, without discovery or an
  /// initial scan: those wait for the foreground. Never creates, adopts or
  /// repairs. Incoming payment ids are collected only with
  /// [collectIncoming], for the background job's payment notifications.
  @useResult
  Future<Result<SyncCompletion, SyncFailure>> refresh(
    WalletKey key, {
    bool collectIncoming = false,
  }) async {
    if (_closed) return const Err(SyncClosedFailure());
    final descriptor = await _catalog.find(key);
    if (descriptor case Err(:final failure)) return Err(failure);
    final result = await _engine.execute(
      (descriptor as Ok<PublicWalletDescriptor, SyncFailure>).value,
      headless: true,
      reason: SyncReason.background,
      discover: false,
      allowInitialScan: false,
      collectIncoming: collectIncoming,
    );
    // Whatever the outcome, the revision it left is republished.
    await _read(key);
    return result;
  }

  /// `revision(key).now`: the revision state this isolate last read for
  /// [key]. The first demand schedules a read; `now` never reads.
  BackgroundRevision revision(WalletKey key) {
    if (!_closed && !_revisions.containsKey(key)) {
      _revisions[key] = const WalletValue.notLoaded();
      unawaited(Future.microtask(() => _read(key)));
    }
    return BackgroundRevision._((this, key));
  }

  Future<void> _read(WalletKey key) async {
    if (_closed) return;
    // A read publishes on [ExistingStores.changes]; only a failure is
    // recorded here.
    if (await _stores.revisions.read(key) case Err(:final failure)) {
      if (!_closed) _revisions[key] = WalletValue.unavailable(failure);
    }
  }

  void _seen(WalletRevisionState state) {
    if (_closed) return;
    _revisions[state.stamp.key] = state.syncFailed
        ? WalletValue.stale(state, state.stamp)
        : WalletValue.ready(state, state.stamp);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _revisions.clear();
    await _changes.cancel();
    await _stores.close();
  }
}

/// `backgroundSync.revision(key)`: read-only, without IO.
extension type const BackgroundRevision._((BackgroundSync, WalletKey) _of) {
  /// The last state read in this isolate: `notLoaded` until a first read,
  /// `stale` after a failed sync, `closed` once the sync is closed.
  WalletValue<WalletRevisionState> get now {
    final (sync, key) = _of;
    if (sync._closed) return const WalletValue.closed();
    return sync._revisions[key] ?? const WalletValue.notLoaded();
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
  int generation, {
  WalletSpender? spender,
}) => Wallet._(projections, spender ?? const _NoSpender(), key, generation);

/// Test wallets hold no native store: every spend command is refused.
final class _NoSpender implements WalletSpender {
  const _NoSpender();

  static Future<Result<T, SyncFailure>> _refused<T>() async =>
      const Err(SyncUnsupportedNetworkFailure());

  @override
  Future<Result<UnsignedSpend, SyncFailure>> build(
    WalletKey key,
    int generation,
    SpendRequest request,
  ) => _refused();

  @override
  Future<Result<UnsignedSpend, SyncFailure>> prepareFunding(
    WalletKey key,
    int generation,
    BitcoinSpendRequest request, {
    required String context,
  }) => _refused();

  @override
  Future<Result<UnsignedSpend, SyncFailure>> bump(
    WalletKey key,
    int generation,
    BumpFeeRequest request,
  ) => _refused();

  @override
  Future<Result<List<UnsignedSpend>, SyncFailure>> consolidate(
    WalletKey key,
    int generation,
    ConsolidationRequest request,
  ) => _refused();

  @override
  Future<Result<SpendReceipt, SyncFailure>> broadcast(SignedSpend spend) =>
      _refused();

  @override
  Future<Result<BitcoinSpendStatus, SyncFailure>> check(
    WalletKey key,
    int generation, {
    String? replacing,
  }) => _refused();

  @override
  Observed<WalletValue<BitcoinSpendStatus>> readiness(WalletKey key) =>
      _Cell(const WalletValue.unavailable(SyncUnsupportedNetworkFailure()));

  @override
  Future<Result<SignatureCheck, SyncFailure>> originalSignatures(
    WalletKey key,
    int generation,
    String txid,
  ) => _refused();

  @override
  Future<Result<String, SyncFailure>> annotate(
    WalletKey key,
    int generation,
    String psbt,
  ) => _refused();

  @override
  Future<Result<BigInt, SyncFailure>> liquidAmountToAddress(
    WalletKey key,
    int generation,
    String pset,
    String address,
  ) => _refused();

  @override
  Future<Result<LiquidPsetEffect, SyncFailure>> liquidEffect(
    WalletKey key,
    int generation,
    String pset,
  ) => _refused();
}
