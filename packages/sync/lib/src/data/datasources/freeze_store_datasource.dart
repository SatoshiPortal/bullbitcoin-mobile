import 'dart:async';
import 'dart:io';

import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../domain/coin_freezes.dart';

/// The freeze store: every user freeze, the import marker and the policy
/// revision, in one database owned by sync.
///
/// Two proofs make a complete import, in this order:
/// 1. the rows and the internal marker, committed in one transaction;
/// 2. the external witness `<path>.provisioned`, written and flushed after.
///
/// The witness outlives the database. Present with a missing, unreadable or
/// unmarked database, it proves freezes were lost: the store is then never
/// recreated, nor the legacy table imported again (it may be out of date).
final class FreezeStoreDatasource {
  final Database _db;

  FreezeStoreDatasource._(this._db);

  static const _version = 1;

  static String witnessPath(String path) => '$path.provisioned';

  /// Whether the witness exists. An unreadable witness throws: it is never
  /// taken for an absent one.
  static bool witnessed(String path) {
    try {
      return File(witnessPath(path)).existsSync();
    } on FileSystemException {
      throw const FreezeStoreUnavailable();
    }
  }

  /// Opens a witnessed store. Throws [FreezeStoreLost] unless the database
  /// exists at its version and carries the import marker.
  static FreezeStoreDatasource openWitnessed(String path) {
    if (!File(path).existsSync()) throw const FreezeStoreLost();
    Database? db;
    try {
      db = sqlite3.open(path, mode: OpenMode.readWrite);
      _configure(db);
      if (db.userVersion != _version) throw const FreezeStoreLost();
      final store = FreezeStoreDatasource._(db);
      if (!store.imported) throw const FreezeStoreLost();
      return store;
    } on FreezeStoreLost {
      db?.dispose();
      rethrow;
    } on SqliteException catch (error) {
      db?.dispose();
      // Contention says nothing about the content.
      if (error.resultCode == 5 || error.resultCode == 6) {
        throw const FreezeStoreUnavailable();
      }
      throw const FreezeStoreLost();
    } on Exception {
      db?.dispose();
      throw const FreezeStoreLost();
    }
  }

  /// Foreground only, before the witness exists: opens or creates the store
  /// for the import. Throws [FreezeStoreUnavailable] when it cannot.
  static FreezeStoreDatasource openForImport(String path) {
    Database? db;
    try {
      File(path).parent.createSync(recursive: true);
      db = sqlite3.open(path);
      _configure(db);
      if (db.userVersion == 0) {
        db.execute('BEGIN IMMEDIATE');
        try {
          if (db.userVersion == 0) {
            db.execute('''CREATE TABLE frozen (
              origin TEXT NOT NULL, txid TEXT NOT NULL, vout INTEGER NOT NULL,
              PRIMARY KEY(origin, txid, vout))''');
            db.execute(
              'CREATE TABLE meta (key TEXT PRIMARY KEY, value INTEGER NOT NULL)',
            );
            db.execute("INSERT INTO meta VALUES ('policy_revision', 0)");
            db.userVersion = _version;
          }
          db.execute('COMMIT');
        } on Object {
          db.execute('ROLLBACK');
          rethrow;
        }
      }
      if (db.userVersion != _version) throw const FreezeStoreUnavailable();
      return FreezeStoreDatasource._(db);
    } on Exception {
      db?.dispose();
      throw const FreezeStoreUnavailable();
    }
  }

  static void _configure(Database db) {
    db.execute('PRAGMA busy_timeout = 1000');
    db.execute('PRAGMA synchronous = FULL');
  }

  /// The internal marker: the import committed.
  bool get imported =>
      _db.select("SELECT 1 FROM meta WHERE key = 'legacy_import'").isNotEmpty;

  /// Commits [legacy] and the marker in one transaction, or, when a previous
  /// run committed them, checks that the stored rows equal [legacy]. Throws
  /// [FreezeStoreUnavailable] on any mismatch: rows are never merged.
  void importOnce(List<FrozenOutpoint> legacy) {
    final expected = legacy.toSet();
    _transaction(() {
      if (!imported) {
        // No freeze is admitted before the witness, so an unmarked store is
        // empty: anything else is not ours to merge.
        if (_all().isNotEmpty) throw const FreezeStoreUnavailable();
        for (final row in expected) {
          _db.execute('INSERT INTO frozen VALUES (?, ?, ?)', [
            row.origin,
            row.outpoint.txId,
            row.outpoint.vout,
          ]);
        }
        if (!_sameRows(expected)) throw const FreezeStoreUnavailable();
        _db.execute("INSERT INTO meta VALUES ('legacy_import', 1)");
      } else if (!_sameRows(expected)) {
        throw const FreezeStoreUnavailable();
      }
    });
  }

  /// Written and flushed only after [importOnce] committed.
  static void writeWitness(String path) {
    try {
      File(witnessPath(path)).writeAsStringSync('1\n', flush: true);
    } on FileSystemException {
      throw const FreezeStoreUnavailable();
    }
  }

  bool _sameRows(Set<FrozenOutpoint> expected) {
    final stored = _all();
    return stored.length == expected.length &&
        stored.toSet().containsAll(expected);
  }

  List<FrozenOutpoint> _all() => [
    for (final row in _db.select('SELECT origin, txid, vout FROM frozen'))
      FrozenOutpoint((
        txId: row['txid'] as String,
        vout: row['vout'] as int,
      ), origin: row['origin'] as String),
  ];

  /// Every freeze, with its revision, from one read.
  ({PolicyRevision revision, List<FrozenOutpoint> rows}) read() {
    _requireImported();
    return _transaction(() => (revision: _revision(), rows: _all()));
  }

  PolicyRevision _revision() => PolicyRevision(
    _db
            .select("SELECT value FROM meta WHERE key = 'policy_revision'")
            .single['value']
        as int,
  );

  /// Runs [body] inside a write transaction, so no other connection can
  /// change a freeze until it returns.
  Future<T> guarded<T>(
    FutureOr<T> Function(List<FrozenOutpoint> rows) body,
  ) async {
    _requireImported();
    _db.execute('BEGIN IMMEDIATE');
    try {
      final result = await body(_all());
      _db.execute('COMMIT');
      return result;
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Adds [rows]; an outpoint already frozen keeps its other attributions.
  PolicyRevision freeze(List<FrozenOutpoint> rows) {
    _requireImported();
    return _transaction(() {
      for (final row in rows) {
        _db.execute('INSERT OR IGNORE INTO frozen VALUES (?, ?, ?)', [
          row.origin,
          row.outpoint.txId,
          row.outpoint.vout,
        ]);
      }
      return _bump();
    });
  }

  /// Removes every attribution of [outpoints]: a coin shown frozen is always
  /// unfreezable, whichever wallet or import froze it.
  PolicyRevision unfreeze(List<Outpoint> outpoints) {
    _requireImported();
    return _transaction(() {
      for (final outpoint in outpoints) {
        _db.execute('DELETE FROM frozen WHERE txid = ? AND vout = ?', [
          outpoint.txId,
          outpoint.vout,
        ]);
      }
      return _bump();
    });
  }

  PolicyRevision _bump() {
    _db.execute(
      "UPDATE meta SET value = value + 1 WHERE key = 'policy_revision'",
    );
    return _revision();
  }

  void _requireImported() {
    if (!imported) throw const FreezeStoreLost();
  }

  T _transaction<T>(T Function() body) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      final result = body();
      _db.execute('COMMIT');
      return result;
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void close() => _db.dispose();
}

/// Transient: the store or the witness cannot be used now. Retried.
final class FreezeStoreUnavailable implements Exception {
  const FreezeStoreUnavailable();
}

/// The witness exists but the store does not hold a complete import.
final class FreezeStoreLost implements Exception {
  const FreezeStoreLost();
}
