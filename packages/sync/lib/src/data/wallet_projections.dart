import 'dart:async';
import 'dart:typed_data';

import 'package:primitives/primitives.dart';

import '../domain/observed.dart';
import '../domain/ports/wallet_revision_reader_port.dart';
import '../domain/sync_failure.dart';
import '../domain/wallet_key.dart';
import '../domain/wallet_revision.dart';
import '../domain/wallet_values.dart';

/// Everything one revision of a wallet publishes, mapped once from the native
/// handle. Never exported: consumers see projections of it.
final class WalletFrame {
  final WalletRevision revision;
  final bool stale;
  final Balances balances;
  final CoinList coins;
  final ChainTransactionList transactions;
  final AddressBook addresses;

  /// Null for Liquid, whose index LWK does not expose.
  final OwnershipIndex? ownership;

  const WalletFrame({
    required this.revision,
    required this.stale,
    required this.balances,
    required this.coins,
    required this.transactions,
    required this.addresses,
    required this.ownership,
  });
}

/// A loaded frame and whether the reader admitted it as the committed
/// revision. A cache served while the writer held the wallet is not admitted.
typedef LoadedFrame = ({WalletFrame frame, bool admitted});

/// Hydrates and maps a wallet without network access. Implementations return
/// [current] itself when its revision and staleness are unchanged, so a
/// revision is mapped at most once.
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
  final _slots = <WalletKey, _Slot>{};
  late final StreamSubscription<WalletRevisionState> _subscription;
  bool _closed = false;

  WalletProjections({
    required this._revisions,
    required Stream<WalletRevisionState> changes,
    required this._source,
  }) {
    _subscription = changes.listen(_changed);
  }

  bool get isClosed => _closed;

  _Slot _slot(WalletKey key) => _slots.putIfAbsent(key, _Slot.new);

  /// The active generation of [key], from revision metadata only.
  Future<Result<int, SyncFailure>> generation(WalletKey key) async {
    if (_closed) return const Err(SyncClosedFailure());
    return switch (await _revisions.read(key)) {
      Ok(:final value) when value.lifecycle == WalletLifecycle.deleted =>
        const Err(SyncNotFoundFailure()),
      Ok(:final value) => Ok(value.stamp.generation),
      Err(:final failure) => Err(failure),
    };
  }

  /// Loads the frame at the latest committed revision, without network.
  /// Calls for one wallet run one after the other.
  Future<Result<WalletRevision, SyncFailure>> load(
    WalletKey key,
    int generation,
  ) async => switch (await _enqueue(key, generation)) {
    Ok(:final value) => Ok(value.frame.revision),
    Err(:final failure) => Err(failure),
  };

  Future<Result<({WalletFrame frame, bool exact}), SyncFailure>> _enqueue(
    WalletKey key,
    int generation,
  ) {
    if (_closed) return Future.value(const Err(SyncClosedFailure()));
    final slot = _slot(key);
    final run = slot.tail.then((_) => _load(key, slot, generation));
    slot.tail = run.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return run;
  }

  Future<Result<({WalletFrame frame, bool exact}), SyncFailure>> _load(
    WalletKey key,
    _Slot slot,
    int generation,
  ) async {
    if (_closed) return const Err(SyncClosedFailure());
    final state = await _revisions.read(key);
    if (_closed) return const Err(SyncClosedFailure());
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
    final current = slot.frame;
    final result = await _source.load(
      key,
      current?.revision.generation == generation ? current : null,
    );
    if (_closed) return const Err(SyncClosedFailure());
    switch (result) {
      case Err(:final failure):
        _fail(slot, failure);
        return Err(failure);
      case Ok(value: (:final frame, :final admitted)):
        // Exact only when the reader admitted this revision and it is still
        // the committed one once the load is over: a witness read before the
        // load would accept a cache the writer has since moved past.
        final settled = await _revisions.read(key);
        if (_closed) return const Err(SyncClosedFailure());
        final exact =
            admitted &&
            settled is Ok<WalletRevisionState, SyncFailure> &&
            settled.value.lifecycle == WalletLifecycle.active &&
            settled.value.stamp == frame.revision;
        if (!identical(frame, slot.frame)) _publish(slot, frame);
        if (frame.revision.generation != generation) {
          return const Err(SyncNotFoundFailure());
        }
        return Ok((frame: frame, exact: exact));
    }
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

  void _publish(_Slot slot, WalletFrame frame) {
    if (slot.frame?.revision.generation != frame.revision.generation) {
      slot.derived.clear();
      slot.deriveFailures.clear();
    }
    slot.frame = frame;
    slot.failure = null;
    slot.notify();
  }

  void _fail(_Slot slot, SyncFailure failure) {
    slot.frame = null;
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
      _source.derive(key, keychain, index).then((result) {
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

  Observed<WalletAddressAt> addressAt(
    WalletKey key,
    int generation,
    int index,
    Keychain keychain,
  ) {
    void schedule() => _derive(key, generation, keychain, index);
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

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription.cancel();
    for (final slot in _slots.values) {
      slot.closeAll();
    }
  }
}

final class _Slot {
  WalletFrame? frame;
  SyncFailure? failure;
  Future<void> tail = Future.value();
  final derived = <(Keychain, int), DerivedAddress>{};
  final deriveFailures = <(Keychain, int), SyncFailure>{};
  final deriving = <(Keychain, int)>{};
  final listeners = <_Listener>{};

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
