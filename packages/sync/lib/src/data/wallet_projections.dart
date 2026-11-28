import 'dart:async';
import 'dart:typed_data';

import 'package:primitives/primitives.dart';
import 'package:secrets/storage.dart'
    show WalletCatalogueSignal, WalletCatalogueStamp;

import '../domain/coin_freezes.dart';
import '../domain/observed.dart';
import '../domain/ports/wallet_revision_reader_port.dart';
import '../domain/ports/wallet_catalog_port.dart';
import '../domain/sync_failure.dart';
import '../domain/wallet_key.dart';
import '../domain/wallet_revision.dart';
import '../domain/wallet_values.dart';
import 'freeze_authority.dart';

/// Everything one revision of a wallet publishes, mapped once from the native
/// handle and reused for every status that revision is later published with.
/// Never exported: consumers see projections of it.
final class WalletFrameData {
  final WalletRevision revision;
  final Balances balances;
  final CoinList coins;
  final ChainTransactionList transactions;
  final AddressBook addresses;

  /// Null for Liquid, whose index LWK does not expose.
  final OwnershipIndex? ownership;

  const WalletFrameData({
    required this.revision,
    required this.balances,
    required this.coins,
    required this.transactions,
    required this.addresses,
    required this.ownership,
  });
}

/// One publication: the mapped [data] of a revision and its status. A status
/// change at the same revision keeps the same data.
final class WalletFrame {
  final WalletFrameData data;
  final bool stale;

  const WalletFrame(this.data, {required this.stale});

  WalletRevision get revision => data.revision;
  Balances get balances => data.balances;
  CoinList get coins => data.coins;
  ChainTransactionList get transactions => data.transactions;
  AddressBook get addresses => data.addresses;
  OwnershipIndex? get ownership => data.ownership;
}

/// A loaded frame and whether the reader admitted it as the committed
/// revision. A cache served while the writer held the wallet is not admitted.
typedef LoadedFrame = ({WalletFrame frame, bool admitted});

/// Hydrates and maps a wallet without network access. Implementations reuse
/// [current]'s data when its revision is unchanged, so a revision is mapped
/// at most once; they return [current] itself when its staleness is
/// unchanged too.
abstract interface class FrameSource {
  Future<Result<LoadedFrame, SyncFailure>> load(
    WalletKey key,
    WalletFrame? current,
  );

  Future<Result<DerivedAddress, SyncFailure>> derive(
    WalletKey key,
    Keychain keychain,
    int index,
  );
}

/// A source whose frame mapping can be performed against an exact catalogue.
abstract interface class CatalogueFrameSource implements FrameSource {
  Future<Result<LoadedFrame, SyncFailure>> loadFrom(
    WalletKey key,
    WalletFrame? current,
    WalletCatalogPort catalog,
  );
}

bool _sameCatalogue(WalletCatalogueStamp? a, WalletCatalogueStamp b) =>
    a != null && identical(a.grant, b.grant) && a.generation == b.generation;

/// The published values of every wallet in this isolate.
///
/// A slot holds one immutable frame. Publication builds the whole frame, then
/// assigns the slot's pointer once, then notifies: every `now` read without
/// an await in between sees the same frame.
///
/// Who republishes after a commit made elsewhere: the revision reader emits on
/// [changes] whenever a read finds a new state, and the foreground calls it
/// after every worker outcome (`WalletNativeRuntime.refresh`). A change for a
/// wallet that has a frame or subscribers schedules a reload here.
final class WalletProjections {
  final WalletRevisionReaderPort _revisions;
  final FrameSource _source;
  final FreezePolicy freezes;
  final _slots = <WalletKey, _Slot>{};
  final WalletCatalogueSignal? catalogueSignal;
  final WalletCatalogPort? Function(WalletCatalogueStamp)? bindCatalogue;
  final _pendingReads = <Future<void>>{};
  late final StreamSubscription<WalletRevisionState> _subscription;
  late final StreamSubscription<void> _freezeSubscription;
  bool _closed = false;
  Future<void>? _closing;

  WalletProjections({
    required this._revisions,
    required Stream<WalletRevisionState> changes,
    required this._source,
    required this.freezes,
    this.catalogueSignal,
    this.bindCatalogue,
  }) {
    _subscription = changes.listen(_changed);
    // A freeze change republishes coins without reloading any wallet.
    _freezeSubscription = freezes.changes.listen((_) {
      if (_closed) return;
      for (final slot in _slots.values.toList()) {
        slot.notify();
      }
    });
  }

  bool get isClosed => _closed;

  _Slot _slot(WalletKey key) => _slots.putIfAbsent(key, _Slot.new);

  /// Retains only the scalar. Does not publish a general-purpose wallet frame
  /// (which would wake observers and schedule address or freeze reads).
  Future<Result<WalletRevision, SyncFailure>> retainBalance(
    WalletKey key,
    WalletCatalogueStamp catalogue, {
    required bool Function() isCurrent,
    required Result<WalletRevisionState, SyncFailure> Function() readCommitted,
    required Future<Result<BigInt, SyncFailure>> Function(WalletRevision)
    mapBalance,
    Future<void> Function()? beforePublication,
  }) {
    bool current() => !_closed && isCurrent();
    if (!current()) return Future.value(const Err(SyncClosedFailure()));
    final slot = _slot(key);
    final run = slot.tail.then<Result<WalletRevision, SyncFailure>>((_) async {
      if (!current()) return const Err(SyncClosedFailure());
      final epoch = slot.epoch;
      final initial = readCommitted();
      if (initial case Err(:final failure)) return Err(failure);
      final stamp =
          (initial as Ok<WalletRevisionState, SyncFailure>).value.stamp;
      final balance = await mapBalance(stamp);
      if (!current()) return const Err(SyncClosedFailure());
      if (balance case Err(:final failure)) return Err(failure);
      if (beforePublication != null) await beforePublication();
      if (!current()) return const Err(SyncClosedFailure());
      if (slot.epoch != epoch) return const Err(SyncNotFoundFailure());
      final settled = readCommitted();
      if (settled case Err(:final failure)) return Err(failure);
      if ((settled as Ok<WalletRevisionState, SyncFailure>).value.stamp !=
          stamp) {
        return const Err(SyncBusyFailure());
      }
      slot.financial = (
        catalogue: catalogue,
        stamp: stamp,
        totalSat: (balance as Ok<BigInt, SyncFailure>).value,
      );
      return Ok(stamp);
    });
    slot.tail = run.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return run;
  }

  /// The active generation of [key], from revision metadata only.
  Future<Result<int, SyncFailure>> generation(WalletKey key) async {
    if (_closed) return const Err(SyncClosedFailure());
    final result = await _trackRead(_revisions.read(key));
    if (_closed) return const Err(SyncClosedFailure());
    return switch (result) {
      Ok(:final value) when value.lifecycle == WalletLifecycle.deleted =>
        const Err(SyncNotFoundFailure()),
      Ok(:final value) => Ok(value.stamp.generation),
      Err(:final failure) => Err(failure),
    };
  }

  // Generation reads and address derivations run outside the per-wallet queue.
  Future<T> _trackRead<T>(Future<T> read) {
    late final Future<void> settled;
    void forget() {
      _pendingReads.remove(settled);
    }

    settled = read.then<void>(
      (_) => forget(),
      onError: (Object _, StackTrace _) => forget(),
    );
    _pendingReads.add(settled);
    return read;
  }

  /// Loads the frame at the latest committed revision, without network.
  /// Calls for one wallet run one after the other.
  Future<Result<WalletRevision, SyncFailure>> load(
    WalletKey key,
    int generation, {
    WalletCatalogueStamp? catalogue,
  }) async => switch (await _enqueue(key, generation, catalogue: catalogue)) {
    Ok(:final value) => Ok(value.frame.revision),
    Err(:final failure) => Err(failure),
  };

  Future<Result<({WalletFrame frame, bool exact}), SyncFailure>> _enqueue(
    WalletKey key,
    int generation, {
    WalletCatalogueStamp? catalogue,
  }) {
    if (_closed) return Future.value(const Err(SyncClosedFailure()));
    final signal = catalogueSignal;
    final stamp = catalogue ?? signal?.capture();
    final bound = stamp == null ? null : bindCatalogue?.call(stamp);
    if (signal != null && bound == null) {
      return Future.value(const Err(SyncClosedFailure()));
    }
    final slot = _slot(key);
    final run = slot.tail.then(
      (_) => _load(key, slot, generation, stamp, bound),
    );
    slot.tail = run.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return run;
  }

  Future<Result<({WalletFrame frame, bool exact}), SyncFailure>> _load(
    WalletKey key,
    _Slot slot,
    int generation,
    WalletCatalogueStamp? catalogue,
    WalletCatalogPort? bound,
  ) async {
    bool currentCatalogue() =>
        !_closed &&
        (catalogue == null || catalogueSignal?.isCurrent(catalogue) == true);
    if (!currentCatalogue()) return const Err(SyncClosedFailure());
    // A delete or re-import seen while this load runs invalidates it.
    final epoch = slot.epoch;
    final state = await _revisions.read(key);
    if (!currentCatalogue()) return const Err(SyncClosedFailure());
    switch (state) {
      case Err(:final failure):
        if (failure is SyncNotFoundFailure) _fail(slot, failure);
        return Err(failure);
      case Ok(:final value):
        if (value.lifecycle == WalletLifecycle.deleted) {
          _fail(slot, const SyncNotFoundFailure());
          return const Err(SyncNotFoundFailure());
        }
        if (value.stamp.generation != generation) {
          return const Err(SyncNotFoundFailure());
        }
    }
    final prior = slot.frame;
    final current =
        prior?.revision.generation == generation &&
            (catalogue == null ||
                _sameCatalogue(slot.frameCatalogue, catalogue))
        ? prior
        : null;
    final source = _source;
    final result = bound != null && source is CatalogueFrameSource
        ? await source.loadFrom(key, current, bound)
        : await source.load(key, current);
    if (!currentCatalogue()) return const Err(SyncClosedFailure());
    switch (result) {
      case Err(:final failure):
        _fail(slot, failure);
        return Err(failure);
      case Ok(value: (:final frame, :final admitted)):
        // Exact only when the reader admitted this revision and it is still
        // the committed one once the load is over: a witness read before the
        // load would accept a cache the writer has since moved past.
        final settled = await _revisions.read(key);
        if (!currentCatalogue()) return const Err(SyncClosedFailure());
        // Nothing is published for a generation a delete or a re-import has
        // ended, even when the mapping started before it.
        if (slot.epoch != epoch) return const Err(SyncNotFoundFailure());
        final WalletRevisionState committed;
        switch (settled) {
          case Err(:final failure):
            if (failure is SyncNotFoundFailure) _fail(slot, failure);
            return Err(failure);
          case Ok(:final value)
              when value.lifecycle == WalletLifecycle.deleted ||
                  value.stamp.generation != frame.revision.generation:
            _fail(slot, const SyncNotFoundFailure());
            return const Err(SyncNotFoundFailure());
          case Ok(:final value):
            committed = value;
        }
        final exact =
            admitted &&
            frame.revision.key == key &&
            frame.revision.generation == generation &&
            committed.lifecycle == WalletLifecycle.active &&
            committed.stamp == frame.revision;
        slot.frameCatalogue = exact ? catalogue : null;
        if (exact &&
            catalogue != null &&
            bound != null &&
            source is CatalogueFrameSource) {
          slot.financial = (
            catalogue: catalogue,
            stamp: frame.revision,
            totalSat: frame.balances.totalSat,
          );
        } else {
          slot.financial = null;
        }
        if (!identical(frame, slot.frame)) _publish(key, slot, frame);
        if (frame.revision.generation != generation) {
          return const Err(SyncNotFoundFailure());
        }
        return Ok((frame: frame, exact: exact));
    }
  }

  BigInt? retainedTotal(WalletCatalogueStamp catalogue, WalletRevision stamp) {
    final value = _slots[stamp.key]?.financial;
    if (_closed ||
        catalogueSignal?.isCurrent(catalogue) != true ||
        value == null ||
        !_sameCatalogue(value.catalogue, catalogue) ||
        value.stamp != stamp) {
      return null;
    }
    return value.totalSat;
  }

  /// Loads, then returns the frame only if the reader admitted it and it was
  /// still the committed revision at the end of the load.
  Future<Result<WalletFrame, SyncFailure>> exact(
    WalletKey key,
    int generation,
  ) async => switch (await _enqueue(key, generation)) {
    // A busy writer can make the reader serve an older revision, or only its
    // cache: protocol decisions must not rely on either.
    Ok(value: (:final frame, exact: true)) => Ok(frame),
    Ok() => const Err(SyncBusyFailure()),
    Err(:final failure) => Err(failure),
  };

  void _publish(WalletKey key, _Slot slot, WalletFrame frame) {
    final generation = frame.revision.generation;
    if (slot.frame?.revision.generation != generation) {
      slot.derived.clear();
      slot.deriveFailures.clear();
    }
    slot.frame = frame;
    slot.failure = null;
    slot.notify();
    // Serve the addresses requested before this generation had a frame.
    slot.requested.removeWhere((request) => request.$1 < generation);
    for (final (requested, keychain, index) in slot.requested.toList()) {
      if (requested == generation) _derive(key, generation, keychain, index);
    }
  }

  void _fail(_Slot slot, SyncFailure failure) {
    slot.epoch++;
    slot.frame = null;
    slot.frameCatalogue = null;
    slot.financial = null;
    slot.failure = failure;
    slot.derived.clear();
    slot.deriveFailures.clear();
    slot.notify();
  }

  void _changed(WalletRevisionState state) {
    final key = state.stamp.key;
    final slot = _slots[key];
    if (_closed || slot == null) return;
    if (state.lifecycle == WalletLifecycle.deleted) {
      _fail(slot, const SyncNotFoundFailure());
      return;
    }
    final frame = slot.frame;
    if (frame == null && slot.listeners.isEmpty) return;
    if (frame != null &&
        frame.revision == state.stamp &&
        frame.stale == state.syncFailed) {
      return;
    }
    if (state.lifecycle != WalletLifecycle.active) return;
    unawaited(load(key, state.stamp.generation));
  }

  void _derive(WalletKey key, int generation, Keychain keychain, int index) {
    final slot = _slot(key);
    final id = (keychain, index);
    if (_closed ||
        slot.derived.containsKey(id) ||
        slot.deriving.contains(id) ||
        slot.frame?.revision.generation != generation) {
      return;
    }
    slot.deriving.add(id);
    unawaited(
      _trackRead(_source.derive(key, keychain, index)).then((result) {
        slot.deriving.remove(id);
        if (_closed || slot.frame?.revision.generation != generation) return;
        switch (result) {
          case Ok(:final value):
            slot.derived[id] = value;
          case Err(:final failure):
            slot.deriveFailures[id] = failure;
        }
        slot.notify();
      }),
    );
  }

  /// A projection of [key]'s frame for a handle of [generation].
  Observed<WalletValue<D>> observe<D extends Object>(
    WalletKey key,
    int generation,
    D? Function(WalletFrame) select, {
    SyncFailure absent = const SyncUnsupportedNetworkFailure(),
  }) => _Projection<D>(this, _slot(key), generation, (frame, slot) {
    final data = select(frame);
    return data == null ? Err(absent) : Ok(data);
  });

  /// [key]'s coins with the freezes applied. Unavailable, never unfrozen,
  /// while the freezes are not known.
  Observed<WalletCoins> coins(WalletKey key, int generation) =>
      _Projection<CoinList>(this, _slot(key), generation, (frame, slot) {
        final snapshot = freezes.snapshot;
        if (snapshot == null) {
          final failure = freezes.failure;
          return failure == null ? null : Err(failure);
        }
        return Ok(slot.frozenCoins(frame.data, snapshot));
      }, onDemand: freezes.demand);

  Observed<WalletAddressAt> addressAt(
    WalletKey key,
    int generation,
    int index,
    Keychain keychain,
  ) {
    void schedule() {
      // Remembered, so a request made before the first load is served once
      // a frame is published, without a hydration per subscriber.
      _slot(key).requested.add((generation, keychain, index));
      _derive(key, generation, keychain, index);
    }

    final projection = _Projection<DerivedAddress>(
      this,
      _slot(key),
      generation,
      (frame, slot) {
        final known =
            frame.addresses.at(index, keychain) ??
            slot.derived[(keychain, index)];
        if (known != null) return Ok(known);
        final failure = slot.deriveFailures[(keychain, index)];
        return failure == null ? null : Err(failure);
      },
      onDemand: schedule,
    );
    schedule();
    return projection;
  }

  Observed<WalletOwnership> owns(
    WalletKey key,
    int generation, {
    Uint8List? script,
    Outpoint? outpoint,
  }) => observe<Ownership>(key, generation, (frame) {
    final index = frame.ownership;
    if (index == null) return null;
    return Ownership(
      (script != null && index.ownsScript(script)) ||
          (outpoint != null && index.ownsOutpoint(outpoint)),
    );
  });

  WalletFrame? frameOf(WalletKey key) => _slots[key]?.frame;

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    try {
      await Future.wait([_subscription.cancel(), _freezeSubscription.cancel()]);
    } finally {
      for (final slot in _slots.values) {
        slot.closeAll();
      }
      await Future.wait([
        for (final slot in _slots.values) slot.tail,
        ..._pendingReads,
      ]);
    }
  }
}

final class _Slot {
  WalletFrame? frame;
  WalletCatalogueStamp? frameCatalogue;
  ({WalletCatalogueStamp catalogue, WalletRevision stamp, BigInt totalSat})?
  financial;

  /// Advanced by every invalidation; a load publishes only if it is unchanged.
  int epoch = 0;
  SyncFailure? failure;
  Future<void> tail = Future.value();
  final derived = <(Keychain, int), DerivedAddress>{};
  final deriveFailures = <(Keychain, int), SyncFailure>{};
  final deriving = <(Keychain, int)>{};

  /// Addresses requested by generation, derived once that generation has a
  /// published frame.
  final requested = <(int, Keychain, int)>{};
  final listeners = <_Listener>{};
  (WalletFrameData, PolicyRevision, CoinList)? _frozen;

  /// [data]'s coins with [snapshot] applied, built once per pair.
  CoinList frozenCoins(WalletFrameData data, FreezeSnapshot snapshot) {
    final memo = _frozen;
    if (memo != null &&
        identical(memo.$1, data) &&
        memo.$2 == snapshot.revision) {
      return memo.$3;
    }
    final coins = data.coins.withFrozen(snapshot.outpoints);
    _frozen = (data, snapshot.revision, coins);
    return coins;
  }

  void notify() {
    for (final listener in listeners.toList()) {
      listener.changed();
    }
  }

  void closeAll() {
    for (final listener in listeners.toList()) {
      listener.close();
    }
    listeners.clear();
  }
}

abstract interface class _Listener {
  void changed();
  void close();
}

/// Reads a slot's current frame. `now` is a pure projection; [onDemand] runs
/// when a value is requested and only schedules work, never inline.
final class _Projection<D extends Object> implements Observed<WalletValue<D>> {
  final WalletProjections _owner;
  final _Slot _slot;
  final int _generation;
  final Result<D, SyncFailure>? Function(WalletFrame, _Slot) _select;
  final void Function()? _onDemand;

  _Projection(
    this._owner,
    this._slot,
    this._generation,
    this._select, {
    this._onDemand,
  });

  @override
  WalletValue<D> get now {
    if (_owner.isClosed) return WalletValue<D>.closed();
    final frame = _slot.frame;
    if (frame == null) {
      final failure = _slot.failure;
      return failure == null
          ? WalletValue<D>.notLoaded()
          : WalletValue<D>.unavailable(failure);
    }
    if (frame.revision.generation != _generation) {
      // A handle never follows a delete or a re-import.
      return WalletValue<D>.unavailable(
        const SyncNotFoundFailure(),
        frame.revision,
      );
    }
    return switch (_select(frame, _slot)) {
      null => WalletValue<D>.notLoaded(),
      Err(:final failure) => WalletValue<D>.unavailable(
        failure,
        frame.revision,
      ),
      Ok(:final value) when frame.stale => WalletValue<D>.stale(
        value,
        frame.revision,
      ),
      Ok(:final value) => WalletValue<D>.ready(value, frame.revision),
    };
  }

  @override
  Stream<WalletValue<D>> watch() {
    late final StreamController<WalletValue<D>> controller;
    late final _Subscriber<D> subscriber;
    controller = StreamController<WalletValue<D>>(
      onListen: () {
        // Register before reading, so no publication falls in between.
        subscriber = _Subscriber<D>(this, controller);
        _slot.listeners.add(subscriber);
        subscriber.emit(now);
        if (_owner.isClosed) {
          subscriber.close();
        } else {
          _onDemand?.call();
        }
      },
      onCancel: () => _slot.listeners.remove(subscriber),
    );
    return controller.stream;
  }
}

final class _Subscriber<D extends Object> implements _Listener {
  final _Projection<D> _projection;
  final StreamController<WalletValue<D>> _controller;
  WalletValue<D>? _last;

  _Subscriber(this._projection, this._controller);

  void emit(WalletValue<D> value) {
    final last = _last;
    if (last != null && last.samePublication(value)) return;
    _last = value;
    _controller.add(value);
  }

  @override
  void changed() => emit(_projection.now);

  @override
  void close() {
    _projection._slot.listeners.remove(this);
    emit(WalletValue<D>.closed());
    unawaited(_controller.close());
  }
}
