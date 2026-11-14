import 'dart:async';

import 'package:primitives/primitives.dart';

import '../domain/coin_freezes.dart';
import '../domain/ports/freeze_store_port.dart';
import '../domain/sync_failure.dart';

/// The freezes this isolate last committed or read, for the projections.
final class FreezeSnapshot {
  final PolicyRevision revision;
  final Set<Outpoint> outpoints;

  FreezeSnapshot(this.revision, Iterable<Outpoint> outpoints)
    : outpoints = Set.unmodifiable(outpoints);
}

/// What wallets and projections use of the freezes: [FreezeAuthority].
abstract interface class FreezePolicy {
  /// The last committed or read freezes of this isolate; null until a read
  /// succeeded, or after a change whose result could not be read back.
  FreezeSnapshot? get snapshot;

  /// Why [snapshot] is null, once known.
  SyncFailure? get failure;

  /// Emits after every change of [snapshot] or [failure].
  Stream<void> get changes;

  /// Schedules a read while [snapshot] is null, never inline.
  void demand();

  /// Every freeze with its attribution, read from the store.
  Future<Result<List<FrozenOutpoint>, SyncFailure>> read();

  /// The outpoints no spend may use, read from the store at call time.
  Future<Result<Set<Outpoint>, SyncFailure>> forbiddenInputs();

  Future<Result<PolicyRevision, SyncFailure>> freeze(List<FrozenOutpoint> rows);

  /// Removes every attribution of [outpoints].
  Future<Result<PolicyRevision, SyncFailure>> unfreeze(
    List<Outpoint> outpoints,
  );
}

/// Foreground owner of the freezes the app keeps behind [FreezeStorePort].
///
/// Every read and change goes to the store; this only remembers the outpoints
/// last read, numbered by a [PolicyRevision] of this isolate, so coins are
/// republished without reloading a wallet. Reads and changes run one after
/// the other here; [guard] holds the store itself.
final class FreezeAuthority implements FreezePolicy {
  final FreezeStorePort _store;
  final _changes = StreamController<void>.broadcast(sync: true);
  Future<void> _tail = Future.value();
  bool _closed = false;
  int _revision = 0;
  FreezeSnapshot? _snapshot;
  SyncFailure? _failure;

  FreezeAuthority(this._store);

  @override
  FreezeSnapshot? get snapshot => _snapshot;

  @override
  SyncFailure? get failure => _failure;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  void demand() {
    if (_snapshot == null && !_closed) unawaited(read());
  }

  @override
  Future<Result<List<FrozenOutpoint>, SyncFailure>> read() => _serial(() async {
    final read = await _store.readAll();
    switch (read) {
      case Ok(:final value):
        final outpoints = {for (final row in value) row.outpoint};
        final known = _snapshot?.outpoints;
        if (known == null ||
            known.length != outpoints.length ||
            !known.containsAll(outpoints)) {
          _publish(PolicyRevision(++_revision), outpoints);
        }
      case Err(:final failure):
        // A failed read does not unfreeze what was read before; with nothing
        // read yet, coins say why they are unavailable.
        if (_snapshot == null) _fail(failure);
    }
    return read;
  });

  @override
  Future<Result<Set<Outpoint>, SyncFailure>> forbiddenInputs() async =>
      switch (await read()) {
        Ok(:final value) => Ok({for (final row in value) row.outpoint}),
        Err(:final failure) => Err(failure),
      };

  /// Runs [body] with the forbidden inputs while no freeze change can commit:
  /// the check and its effect see one policy.
  Future<Result<T, SyncFailure>> guard<T>(
    FutureOr<T> Function(Set<Outpoint> forbidden) body,
  ) async {
    if (_closed) return const Err(SyncClosedFailure());
    return _store.guard(
      (rows) async => body({for (final row in rows) row.outpoint}),
    );
  }

  @override
  Future<Result<PolicyRevision, SyncFailure>> freeze(
    List<FrozenOutpoint> rows,
  ) => _change(() => _store.freeze(rows));

  @override
  Future<Result<PolicyRevision, SyncFailure>> unfreeze(
    List<Outpoint> outpoints,
  ) => _change(() => _store.unfreeze(outpoints));

  /// Commits [write], then republishes what the store holds after it.
  Future<Result<PolicyRevision, SyncFailure>> _change(
    Future<Result<void, SyncFailure>> Function() write,
  ) => _serial(() async {
    if (await write() case Err(:final failure)) return Err(failure);
    final revision = PolicyRevision(++_revision);
    switch (await _store.readAll()) {
      case Ok(:final value):
        _publish(revision, value.map((row) => row.outpoint));
      case Err(:final failure):
        // The change committed but cannot be read back: what was read before
        // is out of date, and coins must not show it.
        _fail(failure);
    }
    return Ok(revision);
  });

  void _publish(PolicyRevision revision, Iterable<Outpoint> outpoints) {
    _snapshot = FreezeSnapshot(revision, outpoints);
    _failure = null;
    if (!_closed) _changes.add(null);
  }

  void _fail(SyncFailure failure) {
    final changed =
        _snapshot != null || _failure.runtimeType != failure.runtimeType;
    _snapshot = null;
    _failure = failure;
    if (changed && !_closed) _changes.add(null);
  }

  Future<Result<T, SyncFailure>> _serial<T>(
    Future<Result<T, SyncFailure>> Function() body,
  ) {
    final run = _tail.then((_) async {
      if (_closed) return Err<T, SyncFailure>(const SyncClosedFailure());
      return body();
    });
    _tail = run.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return run;
  }

  Future<void> close() async {
    if (_closed) return;
    await _tail;
    _closed = true;
    await _changes.close();
  }
}
