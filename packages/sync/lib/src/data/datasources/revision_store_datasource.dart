import 'dart:io';
import '../store_identity.dart';

import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';
import 'package:sqlite3/sqlite3.dart';
import '../../domain/public_wallet_descriptor.dart';
import '../../domain/wallet_key.dart';
import '../../domain/wallet_revision.dart';

/// Bump whenever the pinned native SDK or native store layout changes.
/// Version 1: bull_sdk f4ee00bf61a810d034a397a41a2e40cd7903aa51, legacy BDK/LWK paths.
const writerSchemaVersion = 1;

/// SQL layout of the revision store. Unpublished layouts are not migrated.
const revisionStoreVersion = 1;

/// Intents contain no descriptors, addresses, endpoints or key material.
enum WriteIntent { create, load, receive, sync, delete, repair, rebuild }

final class RevisionRecord {
  final WalletRevisionState state;
  final WriteIntent? intent;
  final int? candidate;
  final int? issued;
  final bool needsSync;
  final String? descriptorHash;
  final String? liquidCachePath;

  const RevisionRecord(
    this.state,
    this.intent,
    this.candidate,
    this.issued,
    this.needsSync,
    this.descriptorHash,
    this.liquidCachePath,
  );
}

/// Metadata is separate from both native stores and the never-deleted lock DB.
/// All mutations require the wallet lease. Transactions contain only synchronous
/// SQLite calls, never native IO or an await. Publication of committed states
/// belongs to [SqliteWalletRevisionReader]; this class only reads and writes rows.
final class RevisionStoreDatasource {
  final Database _db;

  RevisionStoreDatasource._(this._db);

  /// Foreground only: creates the complete schema in one step in a blank file.
  /// A store at another version, or holding tables without a version, is
  /// refused with [RevisionStoreUnavailable].
  static RevisionStoreDatasource openForeground(String path) {
    File(path).parent.createSync(recursive: true);
    final db = sqlite3.open(path);
    try {
      _configure(db);
      if (db.userVersion == 0) {
        db.execute('BEGIN IMMEDIATE');
        try {
          if (db.userVersion == 0) {
            // Version 0 with tables is an unversioned develop layout, not a
            // blank file: refuse it so the caller quarantines it.
            if (db.select('SELECT 1 FROM sqlite_master LIMIT 1').isNotEmpty) {
              throw const RevisionStoreUnavailable();
            }
            db.execute(_schema);
            db.userVersion = revisionStoreVersion;
          }
          db.execute('COMMIT');
        } on Object {
          db.execute('ROLLBACK');
          rethrow;
        }
      }
      if (db.userVersion != revisionStoreVersion) {
        throw const RevisionStoreUnavailable();
      }
      return RevisionStoreDatasource._(db);
    } on Object {
      db.dispose();
      rethrow;
    }
  }

  /// Background and worker: opens the store only if it already exists at the
  /// current version, checked on the same connection. Never creates a file,
  /// a table or a migration.
  static RevisionStoreDatasource openExisting(String path) {
    Database? db;
    try {
      db = sqlite3.open(path, mode: OpenMode.readWrite);
      db.execute('PRAGMA busy_timeout = 5000');
      // Check before configuring: switching the journal mode writes the file.
      if (db.userVersion != revisionStoreVersion) {
        throw const RevisionStoreUnavailable();
      }
      _configure(db);
      return RevisionStoreDatasource._(db);
    } on SqliteException {
      db?.dispose();
      throw const RevisionStoreUnavailable();
    } on Object {
      db?.dispose();
      rethrow;
    }
  }

  static void _configure(Database db) {
    db.execute('PRAGMA busy_timeout = 5000');
    db.execute('PRAGMA journal_mode = WAL');
    db.execute('PRAGMA synchronous = FULL');
  }

  static const _schema = '''CREATE TABLE revisions (
    wallet TEXT NOT NULL, network TEXT NOT NULL,
    generation INTEGER NOT NULL, revision INTEGER NOT NULL,
    lifecycle TEXT NOT NULL, intent TEXT, candidate INTEGER,
    issued INTEGER, needs_sync INTEGER NOT NULL DEFAULT 0,
    initialized_schema INTEGER NOT NULL DEFAULT 0,
    descriptor_hash TEXT, liquid_cache_path TEXT,
    sync_failed INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY(wallet, network))''';

  static String _network(WalletKey key) => switch (key.network) {
    BitcoinNetwork() => 'bitcoin/${key.network.env.name}',
    LiquidNetwork() => 'liquid/${key.network.env.name}',
  };

  @internal
  RevisionRecord? record(WalletKey key) {
    final rows = _db.select(
      'SELECT * FROM revisions WHERE wallet = ? AND network = ?',
      [key.id, _network(key)],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    final intent = row['intent'] as String?;
    return RevisionRecord(
      WalletRevisionState(
        stamp: WalletRevision(
          key: key,
          generation: row['generation'] as int,
          revision: row['revision'] as int,
        ),
        lifecycle: WalletLifecycle.values.byName(row['lifecycle'] as String),
        initializedSchema: row['initialized_schema'] as int,
        issuedReceiveIndex: row['issued'] as int?,
        syncFailed: row['sync_failed'] == 1,
      ),
      intent == null ? null : WriteIntent.values.byName(intent),
      row['candidate'] as int?,
      row['issued'] as int?,
      row['needs_sync'] == 1,
      row['descriptor_hash'] as String?,
      row['liquid_cache_path'] as String?,
    );
  }

  /// The pending candidate is reserved durably before native reveal; it is not
  /// yet an issued address. A tombstone is durable before the first unlink.
  @internal
  void begin(WalletKey key, WriteIntent intent, {int? candidate}) {
    final old = record(key);
    if (old?.intent != null && intent != WriteIntent.delete) {
      throw StateError('Unreconciled write');
    }
    final oldGeneration = old?.state.stamp.generation ?? 0;
    final generation =
        oldGeneration +
        (intent == WriteIntent.delete ||
                (intent == WriteIntent.create &&
                    (old == null ||
                        old.state.lifecycle == WalletLifecycle.deleted))
            ? 1
            : 0);
    final lifecycle = intent == WriteIntent.delete
        ? WalletLifecycle.deleted
        : WalletLifecycle.pendingWrite;
    _db.execute(
      '''INSERT INTO revisions
      (wallet, network, generation, revision, lifecycle, intent, candidate,
       issued, needs_sync) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(wallet, network) DO UPDATE SET
       generation=excluded.generation, lifecycle=excluded.lifecycle,
       intent=excluded.intent, candidate=excluded.candidate''',
      [
        key.id,
        _network(key),
        generation,
        old?.state.stamp.revision ?? 0,
        lifecycle.name,
        intent.name,
        candidate,
        old?.issued,
        (old?.needsSync ?? false) ? 1 : 0,
      ],
    );
  }

  /// Candidate reservation belongs to the receive intent already covering
  /// native session construction (which itself may touch the store).
  @internal
  void reserveReceive(WalletKey key, int index) {
    if (record(key)?.intent != WriteIntent.receive) {
      throw StateError('No receive intent');
    }
    _db.execute(
      'UPDATE revisions SET candidate=? WHERE wallet=? AND network=?',
      [index, key.id, _network(key)],
    );
  }

  /// Escalates an interrupted sync to explicit repair without clearing its
  /// uncertainty or publishing a successful revision.
  @internal
  void requireRepair(WalletKey key) {
    _db.execute(
      "UPDATE revisions SET intent='repair', needs_sync=1 "
      'WHERE wallet=? AND network=?',
      [key.id, _network(key)],
    );
  }

  /// Reserve reconstruction before creating a replacement store. Recovery must
  /// replay issued indices even when the new store already exists after a crash.
  @internal
  void requireRebuild(WalletKey key) {
    _db.execute(
      "UPDATE revisions SET intent='rebuild', needs_sync=1 WHERE wallet=? AND network=?",
      [key.id, _network(key)],
    );
  }

  /// Clears a proven non-mutating attempt without invalidating snapshots.
  /// A successful no-op sync preserves health; a failed sync marks it stale.
  @internal
  WalletRevisionState? cancelUnchanged(
    WalletKey key,
    RevisionRecord? previous, {
    bool syncSucceeded = false,
  }) {
    final pending = record(key);
    if (pending?.intent != WriteIntent.load &&
        pending?.intent != WriteIntent.sync) {
      throw StateError('Only a non-mutating load or sync may be cancelled');
    }
    if (previous == null) {
      _db.execute('DELETE FROM revisions WHERE wallet=? AND network=?', [
        key.id,
        _network(key),
      ]);
    } else {
      _db.execute(
        'UPDATE revisions SET lifecycle=?, intent=NULL, candidate=NULL, sync_failed=? WHERE wallet=? AND network=?',
        [
          previous.state.lifecycle.name,
          (pending?.intent == WriteIntent.sync && !syncSucceeded) ||
                  previous.state.syncFailed
              ? 1
              : 0,
          key.id,
          _network(key),
        ],
      );
      return record(key)?.state;
    }
    return null;
  }

  @internal
  WalletRevisionState finish(
    WalletKey key, {
    int? issued,
    bool? needsSync,
    bool? syncFailed,
    PublicWalletDescriptor? initializedDescriptor,
    String? liquidCachePath,
  }) {
    _db.execute('BEGIN IMMEDIATE');
    late WalletRevisionState state;
    try {
      final old = record(key);
      if (old == null || old.intent == null) throw StateError('No intent');
      final deleted = old.intent == WriteIntent.delete;
      final creating = old.intent == WriteIntent.create;
      _db.execute(
        '''UPDATE revisions SET revision=revision+1,
        lifecycle=?, intent=NULL, candidate=NULL, issued=?, needs_sync=?, initialized_schema=?, descriptor_hash=?, liquid_cache_path=?, sync_failed=?
        WHERE wallet=? AND network=?''',
        [
          (deleted ? WalletLifecycle.deleted : WalletLifecycle.active).name,
          deleted ? null : (issued ?? (creating ? null : old.issued)),
          (needsSync ?? (creating ? false : old.needsSync)) ? 1 : 0,
          deleted
              ? 0
              : {
                  WriteIntent.create,
                  WriteIntent.load,
                  WriteIntent.repair,
                  WriteIntent.rebuild,
                }.contains(old.intent)
              ? writerSchemaVersion
              : old.state.initializedSchema,
          deleted
              ? null
              : initializedDescriptor == null
              ? old.descriptorHash
              : descriptorDigest(initializedDescriptor),
          deleted
              ? null
              : initializedDescriptor == null
              ? old.liquidCachePath
              : liquidCachePath,
          (deleted || creating || needsSync == false
                  ? false
                  : syncFailed ?? old.state.syncFailed)
              ? 1
              : 0,
          key.id,
          _network(key),
        ],
      );
      final committed = record(key);
      if (committed == null) throw StateError('Missing revision');
      state = committed.state;
      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }
    return state;
  }

  void close() => _db.dispose();
}

/// Missing, or at a version this build neither creates nor migrates.
final class RevisionStoreUnavailable implements Exception {
  const RevisionStoreUnavailable();
}
