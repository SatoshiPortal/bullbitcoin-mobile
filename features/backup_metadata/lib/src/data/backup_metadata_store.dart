import 'dart:io';
import 'dart:math';

import 'package:backup_storage/backup_storage.dart';
import 'package:sqlite3/sqlite3.dart';

typedef BackupScope = ({
  BackupDestination destination,
  String account,
  String group,
  String lineage,
  int generation,
});

typedef BackupIntent = ({
  String name,
  String digest,
  String envelopeDigest,
  String? objectId,
});

typedef BackupGeneration = ({
  String objectId,
  String digest,
  String envelopeDigest,
  DateTime verifiedAt,
});

typedef BackupSelection = ({
  BackupDestination? destination,
  String? account,
  int generation,
  String lineage,
  Set<String> groups,
});

String randomHex(int bytes) {
  final random = Random.secure();
  return List.generate(
    bytes,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// The key of the encrypted journal, spelled as the SQLCipher raw-key literal
/// (`x'<hex>'`). Null when the keystore cannot supply it: the store then
/// refuses to open and never falls back to an unencrypted file.
typedef BackupMetadataKey = Future<String?> Function();

/// Both isolates must use the same app-private path. The guard's write
/// transaction is independent of the state database's durable commits.
///
/// One encrypted database owns the journal, the configured destination and
/// the group identity mapping together, partitioned by view: each view has
/// its own selection, lineage and group ids, so nothing a view records is
/// visible from, or deletable by, another. It has never shipped, so there is
/// no earlier on-disk layout to migrate from.
///
/// Remote deletion only ever follows a journaled object id of the view's own
/// lineage. A missing, unreadable or inconsistent journal therefore deletes
/// nothing: it never trusts a file name found at the destination.
final class BackupMetadataStore {
  /// The only supported layout.
  static const schemaVersion = 1;

  final String path;
  final BackupMetadataKey key;
  final Duration lockTimeout;

  const BackupMetadataStore({
    required this.path,
    required this.key,
    this.lockTimeout = const Duration(seconds: 30),
  });

  /// Runs [action] on [view]'s state under the cross-isolate guard.
  Future<T> locked<T>(
    Future<T> Function(BackupMetadataState) action, {
    required String view,
  }) async {
    await File(path).parent.create(recursive: true);
    final guard = sqlite3.open('$path.guard');
    try {
      await _acquire(guard);
      final state = await _open(OpenMode.readWriteCreate);
      try {
        state.execute('PRAGMA synchronous = FULL');
        _initialize(state);
        _ensureView(state, view);
        return await action(BackupMetadataState._(state, view));
      } finally {
        state.close();
      }
    } finally {
      // Closing rolls back the guard transaction, including on error.
      guard.close();
    }
  }

  /// The installation-stable id of one reference and environment in [view].
  ///
  /// It uses its own short-lived connection so callers outside [locked] can
  /// resolve ids without contending with the guard. It never creates the
  /// journal: null means it has not been prepared yet.
  Future<String?> groupId(
    String view,
    String reference,
    String environment,
  ) async {
    if (!File(path).existsSync()) return null;
    final state = await _open(OpenMode.readWrite);
    try {
      state.execute('PRAGMA busy_timeout = 3000');
      if (state.userVersion != schemaVersion) return null;
      final key = [view, reference, environment];
      state.execute('''
        INSERT INTO group_ids (view, secret_ref, environment, group_id)
        VALUES (?, ?, ?, lower(hex(randomblob(16))))
        ON CONFLICT (view, secret_ref, environment) DO NOTHING
      ''', key);
      return state.select('''
        SELECT group_id FROM group_ids
        WHERE view = ? AND secret_ref = ? AND environment = ?
      ''', key).single['group_id']
          as String;
    } finally {
      state.close();
    }
  }

  Future<Database> _open(OpenMode mode) async {
    final literal = await key();
    if (literal == null) throw const BackupMetadataStoreNotReady();
    final database = sqlite3.open(path, mode: mode);
    try {
      database.execute('PRAGMA busy_timeout = 2000');
      if (database.select('PRAGMA cipher').isEmpty) {
        throw const BackupMetadataStoreNotReady();
      }
      database.execute("PRAGMA cipher = 'chacha20'");
      database.execute('PRAGMA key = "$literal"');
      // PRAGMA key succeeds for a wrong key: only a read proves it.
      database.select('SELECT count(*) FROM sqlite_master');
      return database;
    } catch (_) {
      database.close();
      rethrow;
    }
  }

  void _ensureView(Database state, String view) {
    state.execute(
      '''INSERT INTO selection (view, generation, lineage) VALUES (?, 0, ?)
         ON CONFLICT (view) DO NOTHING''',
      [view, randomHex(16)],
    );
  }

  Future<void> _acquire(Database guard) async {
    final waiting = Stopwatch()..start();
    guard.execute('PRAGMA busy_timeout = 0');
    while (true) {
      try {
        guard.execute('BEGIN IMMEDIATE');
        return;
      } on SqliteException catch (error) {
        if (error.resultCode != SqlError.SQLITE_BUSY ||
            waiting.elapsed >= lockTimeout) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  }

  void _initialize(Database state) {
    final version = state.userVersion;
    if (version == schemaVersion) return;
    if (version != 0) {
      throw const FormatException('Unknown backup metadata store version');
    }
    state.execute('BEGIN IMMEDIATE');
    try {
      _createSchema(state);
      state.userVersion = schemaVersion;
      state.execute('COMMIT');
    } finally {
      if (state.autocommit == false) state.execute('ROLLBACK');
    }
  }

  void _createSchema(Database state) {
    state.execute('''
      CREATE TABLE selection (
        view TEXT PRIMARY KEY, destination TEXT, account TEXT,
        generation INTEGER NOT NULL, lineage TEXT NOT NULL
      );
      CREATE TABLE included_groups (
        view TEXT NOT NULL, id TEXT NOT NULL, PRIMARY KEY (view, id)
      );
      CREATE TABLE intents (
        destination TEXT NOT NULL, account TEXT NOT NULL, group_id TEXT NOT NULL,
        lineage TEXT NOT NULL, generation INTEGER NOT NULL, name TEXT NOT NULL,
        digest TEXT NOT NULL, envelope_digest TEXT NOT NULL, object_id TEXT,
        PRIMARY KEY (destination, account, group_id, lineage, generation)
      );
      CREATE TABLE verified (
        sequence INTEGER PRIMARY KEY, destination TEXT NOT NULL,
        account TEXT NOT NULL, group_id TEXT NOT NULL, lineage TEXT NOT NULL,
        generation INTEGER NOT NULL, object_id TEXT NOT NULL, digest TEXT NOT NULL,
        verified_at INTEGER NOT NULL, envelope_digest TEXT NOT NULL,
        UNIQUE (destination, account, lineage, object_id)
      );
      CREATE TABLE group_ids (
        view TEXT NOT NULL, secret_ref TEXT NOT NULL, environment TEXT NOT NULL,
        group_id TEXT NOT NULL UNIQUE,
        PRIMARY KEY (view, secret_ref, environment)
      );
    ''');
  }
}

/// The journal key is unavailable or the journal cannot be opened: no
/// operation proceeds, and none ever falls back to an unencrypted file.
final class BackupMetadataStoreNotReady implements Exception {
  const BackupMetadataStoreNotReady();
}

/// State operations scoped to a held guard. Each operation is committed before
/// control returns to the caller.
final class BackupMetadataState {
  static const _scope =
      'destination = ? AND account = ? AND group_id = ? AND lineage = ? AND generation = ?';

  final Database _db;
  final String _view;

  BackupMetadataState._(this._db, this._view);

  BackupSelection get selection {
    final row = _db.select('SELECT * FROM selection WHERE view = ?', [
      _view,
    ]).single;
    final destination = row['destination'] as String?;
    return (
      destination: destination == null
          ? null
          : BackupDestination.values.byName(destination),
      account: row['account'] as String?,
      generation: row['generation'] as int,
      lineage: row['lineage'] as String,
      groups: {
        for (final group in _db.select(
          'SELECT id FROM included_groups WHERE view = ?',
          [_view],
        ))
          group['id'] as String,
      },
    );
  }

  void configure({
    required BackupDestination? destination,
    required String? account,
    required Set<String> groups,
  }) {
    final previous = selection;
    final changed =
        previous.destination != destination || previous.account != account;
    _atomic(() {
      _db.execute(
        'UPDATE selection SET destination = ?, account = ?, generation = ? WHERE view = ?',
        [
          destination?.name,
          account,
          previous.generation + (changed ? 1 : 0),
          _view,
        ],
      );
      _db.execute('DELETE FROM included_groups WHERE view = ?', [_view]);
      for (final group in groups) {
        _db.execute('INSERT INTO included_groups VALUES (?, ?)', [
          _view,
          group,
        ]);
      }
    });
  }

  BackupIntent? intent(BackupScope scope) {
    final rows = _db.select(
      'SELECT name, digest, envelope_digest, object_id FROM intents WHERE $_scope',
      _parameters(scope),
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return (
      name: row['name'] as String,
      digest: row['digest'] as String,
      envelopeDigest: row['envelope_digest'] as String,
      objectId: row['object_id'] as String?,
    );
  }

  void begin(BackupScope scope, BackupIntent intent) =>
      _db.execute('INSERT INTO intents VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', [
        ..._parameters(scope),
        intent.name,
        intent.digest,
        intent.envelopeDigest,
        intent.objectId,
      ]);

  void recordCreated(BackupScope scope, String objectId) => _db.execute(
    'UPDATE intents SET object_id = ? WHERE $_scope',
    [objectId, ..._parameters(scope)],
  );

  void acknowledge(
    BackupScope scope,
    BackupIntent intent, {
    required String objectId,
    required DateTime verifiedAt,
  }) => _atomic(() {
    _db.execute(
      '''INSERT INTO verified
        (destination, account, group_id, lineage, generation, object_id, digest, verified_at, envelope_digest)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        ..._parameters(scope),
        objectId,
        intent.digest,
        verifiedAt.millisecondsSinceEpoch,
        intent.envelopeDigest,
      ],
    );
    discardIntent(scope);
  });

  void discardIntent(BackupScope scope) =>
      _db.execute('DELETE FROM intents WHERE $_scope', _parameters(scope));

  List<BackupGeneration> verified(BackupScope scope) => [
    for (final row in _db.select(
      'SELECT * FROM verified WHERE $_scope ORDER BY sequence DESC',
      _parameters(scope),
    ))
      (
        objectId: row['object_id'] as String,
        digest: row['digest'] as String,
        envelopeDigest: row['envelope_digest'] as String,
        verifiedAt: DateTime.fromMillisecondsSinceEpoch(
          row['verified_at'] as int,
          isUtc: true,
        ),
      ),
  ];

  Set<String> owned(
    BackupDestination destination,
    String account,
    String lineage,
  ) => {
    for (final row in _db.select(
      '''SELECT object_id FROM verified WHERE destination = ? AND account = ? AND lineage = ?
         UNION SELECT object_id FROM intents WHERE destination = ? AND account = ?
         AND lineage = ? AND object_id IS NOT NULL''',
      [destination.name, account, lineage, destination.name, account, lineage],
    ))
      row['object_id'] as String,
  };

  void forget(
    BackupDestination destination,
    String account,
    String lineage,
    String objectId,
  ) => _atomic(() {
    final key = [destination.name, account, lineage, objectId];
    const match =
        'destination = ? AND account = ? AND lineage = ? AND object_id = ?';
    _db.execute('DELETE FROM verified WHERE $match', key);
    _db.execute('DELETE FROM intents WHERE $match', key);
  });

  void _atomic(void Function() write) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      write();
      _db.execute('COMMIT');
    } finally {
      if (_db.autocommit == false) _db.execute('ROLLBACK');
    }
  }

  List<Object> _parameters(BackupScope scope) => [
    scope.destination.name,
    scope.account,
    scope.group,
    scope.lineage,
    scope.generation,
  ];
}
