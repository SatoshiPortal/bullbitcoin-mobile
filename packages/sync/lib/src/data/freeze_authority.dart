import 'dart:async';

import 'package:primitives/primitives.dart';

import '../domain/coin_freezes.dart';
import '../domain/ports/legacy_freeze_source_port.dart';
import '../domain/sync_failure.dart';
import 'datasources/freeze_store_datasource.dart';

/// The freezes this isolate last committed or read, for the projections.
final class FreezeSnapshot {
  final PolicyRevision revision;
  final Set<Outpoint> outpoints;

  FreezeSnapshot(this.revision, Iterable<Outpoint> outpoints)
    : outpoints = Set.unmodifiable(outpoints);
}

/// What wallets and projections use of the freezes. [FreezeAuthority] in
/// production; package tests and `testing.dart` supply their own.
abstract interface class FreezePolicy {
  /// The last committed or read freezes of this isolate; null until the
  /// import is complete and the store has been read.
  FreezeSnapshot? get snapshot;

  /// Why [snapshot] is null, once known.
  SyncFailure? get failure;

  /// Emits after every change of [snapshot] or [failure].
  Stream<void> get changes;

  /// Schedules the import and a first read, never inline.
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

  /// Checks the store, its marker and the witness together again.
  Future<Result<void, SyncFailure>> recover();
}

/// Foreground owner of the freeze store: the one-time import, every freeze
/// change and the exact reads spend admission relies on.
///
/// Operations run one after the other in this isolate. Store transactions
/// are `BEGIN IMMEDIATE`, so a second connection waits or fails busy, never
/// interleaves. Until the import is witnessed, every operation fails with
/// [SyncFreezeImportRequiredFailure] and is retried on the next call; once
/// the store is found lost, with [SyncFreezeStoreLostFailure] until
/// [recover] finds it whole again.
final class FreezeAuthority implements FreezePolicy {
  final String _path;
  final LegacyFreezeSourcePort _legacy;
  final _changes = StreamController<void>.broadcast(sync: true);
  Future<void> _tail = Future.value();
  FreezeStoreDatasource? _store;
  bool _lost = false;
  bool _closed = false;
  FreezeSnapshot? _snapshot;
  SyncFailure? _failure;

  FreezeAuthority({required this._path, required this._legacy});

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

  /// Imports if needed, then succeeds once the store is witnessed whole.
  Future<Result<void, SyncFailure>> ready() =>
      _run((_) => const Ok<void, SyncFailure>(null));

  @override
  Future<Result<List<FrozenOutpoint>, SyncFailure>> read() => _run((store) {
    final read = store.read();
    _publish(FreezeSnapshot(read.revision, read.rows.map((r) => r.outpoint)));
    return Ok(read.rows);
  });

  @override
  Future<Result<Set<Outpoint>, SyncFailure>> forbiddenInputs() async =>
      switch (await read()) {
        Ok(:final value) => Ok({for (final row in value) row.outpoint}),
        Err(:final failure) => Err(failure),
      };

  /// Runs [body] with the forbidden inputs while no freeze change can commit,
  /// in this isolate or another: the check and its effect see one policy.
  Future<Result<T, SyncFailure>> guard<T>(
    FutureOr<T> Function(Set<Outpoint> forbidden) body,
  ) => _runAsync(
    (store) async => Ok(
      await store.guarded(
        (rows) => body({for (final row in rows) row.outpoint}),
      ),
    ),
  );

  @override
  Future<Result<PolicyRevision, SyncFailure>> freeze(
    List<FrozenOutpoint> rows,
  ) => _run((store) => Ok(_after(store, store.freeze(rows))));

  @override
  Future<Result<PolicyRevision, SyncFailure>> unfreeze(
    List<Outpoint> outpoints,
  ) => _run((store) => Ok(_after(store, store.unfreeze(outpoints))));

  /// Explicit recovery after [SyncFreezeStoreLostFailure]: checks the store,
  /// its marker and the witness together again. Never recreates the store,
  /// never imports the legacy table again, never removes the witness.
  @override
  Future<Result<void, SyncFailure>> recover() {
    _lost = false;
    return ready();
  }

  PolicyRevision _after(FreezeStoreDatasource store, PolicyRevision revision) {
    final read = store.read();
    _publish(FreezeSnapshot(read.revision, read.rows.map((r) => r.outpoint)));
    return revision;
  }

  void _publish(FreezeSnapshot snapshot) {
    final changed =
        _failure != null || _snapshot?.revision != snapshot.revision;
    _snapshot = snapshot;
    _failure = null;
    if (changed && !_closed) _changes.add(null);
  }

  void _fail(SyncFailure failure) {
    final changed =
        _snapshot != null || _failure.runtimeType != failure.runtimeType;
    _snapshot = null;
    _failure = failure;
    if (changed && !_closed) _changes.add(null);
  }

  Future<Result<T, SyncFailure>> _run<T>(
    Result<T, SyncFailure> Function(FreezeStoreDatasource store) body,
  ) => _runAsync((store) async => body(store));

  Future<Result<T, SyncFailure>> _runAsync<T>(
    Future<Result<T, SyncFailure>> Function(FreezeStoreDatasource store) body,
  ) {
    final run = _tail.then((_) async {
      if (_closed) return Err<T, SyncFailure>(const SyncClosedFailure());
      final opened = await _open();
      if (opened case Err(:final failure)) {
        _fail(failure);
        return Err<T, SyncFailure>(failure);
      }
      final store = (opened as Ok<FreezeStoreDatasource, SyncFailure>).value;
      try {
        return await body(store);
      } on FreezeStoreLost {
        return Err<T, SyncFailure>(_lose());
      } on Exception {
        // A busy or failing store is not a lost one: the next call retries.
        _forget();
        return Err<T, SyncFailure>(const SyncStorageFailure());
      }
    });
    _tail = run.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return run;
  }

  /// The store, importing first when no witness exists yet.
  Future<Result<FreezeStoreDatasource, SyncFailure>> _open() async {
    final open = _store;
    if (open != null) return Ok(open);
    if (_lost) return const Err(SyncFreezeStoreLostFailure());
    try {
      if (FreezeStoreDatasource.witnessed(_path)) {
        return Ok(_store = FreezeStoreDatasource.openWitnessed(_path));
      }
    } on FreezeStoreLost {
      return Err(_lose());
    } on FreezeStoreUnavailable {
      // An unreadable witness is not an absent one: nothing is imported.
      return const Err(SyncStorageFailure());
    }
    // Not witnessed: the legacy table is the only truth, and nothing has
    // been admitted since it was written.
    final legacy = await _legacy.readAll();
    if (legacy case Err()) return const Err(SyncFreezeImportRequiredFailure());
    final rows = (legacy as Ok<List<FrozenOutpoint>, SyncFailure>).value;
    FreezeStoreDatasource? store;
    try {
      store = FreezeStoreDatasource.openForImport(_path);
      store.importOnce(rows);
      FreezeStoreDatasource.writeWitness(_path);
      return Ok(_store = store);
    } on Exception {
      store?.close();
      return const Err(SyncFreezeImportRequiredFailure());
    }
  }

  SyncFailure _lose() {
    _forget();
    _lost = true;
    return const SyncFreezeStoreLostFailure();
  }

  void _forget() {
    _store?.close();
    _store = null;
  }

  Future<void> close() async {
    if (_closed) return;
    await _tail;
    _closed = true;
    _forget();
    await _changes.close();
  }
}
