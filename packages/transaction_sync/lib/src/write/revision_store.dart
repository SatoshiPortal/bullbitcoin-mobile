import 'dart:async';
import 'dart:io';
import 'store_identity.dart';

import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';
import 'package:sqlite3/sqlite3.dart';
import '../../transaction_sync.dart';

/// Bump whenever the pinned native SDK or native store layout changes.
/// Version 1: bull_sdk f4ee00bf61a810d034a397a41a2e40cd7903aa51, legacy BDK/LWK paths.
const writerSchemaVersion = 1;

/// Intents contain no descriptors, addresses, endpoints or key material.
enum WriteIntent { create, load, receive, sync, delete, repair }

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
/// SQLite calls, never native IO or an await. Share this instance with readers
/// for in-isolate notifications; read again on resume for cross-isolate writes.
final class RevisionStore implements WalletRevisionReader {
  final Database _db;
  final _changes = StreamController<WalletRevisionState>.broadcast();
  final _published = <WalletKey, WalletRevisionState>{};

  RevisionStore(String path) : _db = _open(path);

  static Database _open(String path) {
    File(path).parent.createSync(recursive: true);
    final db = sqlite3.open(path);
    try {
      db.execute('PRAGMA busy_timeout = 5000');
      db.execute('PRAGMA journal_mode = WAL');
      db.execute('PRAGMA synchronous = FULL');
      db.execute('BEGIN IMMEDIATE');
      db.execute('''CREATE TABLE IF NOT EXISTS revisions (
        wallet TEXT NOT NULL, network TEXT NOT NULL,
        generation INTEGER NOT NULL, revision INTEGER NOT NULL,
        lifecycle TEXT NOT NULL, intent TEXT, candidate INTEGER,
        issued INTEGER, needs_sync INTEGER NOT NULL DEFAULT 0,
        initialized_schema INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY(wallet, network))''');
      if (!db
          .select('PRAGMA table_info(revisions)')
          .any((row) => row['name'] == 'initialized_schema')) {
        db.execute(
          'ALTER TABLE revisions ADD COLUMN initialized_schema INTEGER NOT NULL DEFAULT 0',
        );
      }
      final columns = db
          .select('PRAGMA table_info(revisions)')
          .map((row) => row['name'])
          .toSet();
      for (final column in ['descriptor_hash', 'liquid_cache_path']) {
        if (!columns.contains(column)) {
          db.execute('ALTER TABLE revisions ADD COLUMN $column TEXT');
        }
      }
      db.execute('COMMIT');
      return db;
    } on Exception {
      db.dispose();
      rethrow;
    }
  }

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

  @internal
  WalletRevision finish(
    WalletKey key, {
    int? issued,
    bool? needsSync,
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
        lifecycle=?, intent=NULL, candidate=NULL, issued=?, needs_sync=?, initialized_schema=?, descriptor_hash=?, liquid_cache_path=?
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
    _publish(state);
    return state.stamp;
  }

  @override
  Future<Result<WalletRevisionState, TransactionSyncFailure>> read(
    WalletKey key,
  ) async {
    try {
      final value = record(key);
      if (value == null) return const Err(TransactionSyncNotFoundFailure());
      // Also bridges a completed compute worker: its caller reads the persisted
      // revision here. Resume/open uses the same path for background commits.
      _publish(value.state);
      return Ok(value.state);
    } on SqliteException catch (error) {
      return Err(
        error.resultCode == 5
            ? const TransactionSyncBusyFailure()
            : const TransactionSyncStorageFailure(),
      );
    }
  }

  void _publish(WalletRevisionState state) {
    final previous = _published[state.stamp.key];
    if (previous?.stamp == state.stamp &&
        previous?.lifecycle == state.lifecycle &&
        previous?.initializedSchema == state.initializedSchema) {
      return;
    }
    _published[state.stamp.key] = state;
    _changes.add(state);
  }

  Stream<WalletRevisionState> get changes => _changes.stream;

  @override
  Stream<WalletRevisionState> watch(WalletKey key) =>
      _changes.stream.where((state) => state.stamp.key == key);

  Future<void> close() async {
    _db.dispose();
    await _changes.close();
  }
}
