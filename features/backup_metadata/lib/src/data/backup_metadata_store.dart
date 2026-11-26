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

/// Both isolates must use the same app-private path. The guard's write
/// transaction is independent of the state database's durable commits.
///
/// One database owns the journal, the configured destination and the group
/// identity mapping together. It has never shipped, so there is no earlier
/// on-disk layout to migrate from.
final class BackupMetadataStore {
  /// The only supported layout. A headless open requires exactly this version.
  static const schemaVersion = 1;

  final String path;
  final Duration lockTimeout;

  /// A background open never creates, initializes or migrates the owner
  /// database: it proceeds only on a database the foreground already prepared
  /// at [schemaVersion].
  final bool background;

  const BackupMetadataStore({
    required this.path,
    this.lockTimeout = const Duration(seconds: 30),
    this.background = false,
  });

  Future<T> locked<T>(Future<T> Function(BackupMetadataState) action) async {
    if (background) {
      _requireOwned();
    } else {
      await File(path).parent.create(recursive: true);
    }
    final guard = sqlite3.open('$path.guard');
    try {
      await _acquire(guard);
      final state = sqlite3.open(
        path,
        mode: background ? OpenMode.readWrite : OpenMode.readWriteCreate,
      );
      try {
        state.execute('PRAGMA synchronous = FULL');
        if (background) {
          if (state.userVersion != schemaVersion) {
            throw const BackupMetadataStoreNotReady();
          }
        } else {
          _initialize(state);
        }
        return await action(BackupMetadataState._(state));
      } finally {
        state.close();
      }
    } finally {
      // Closing rolls back the guard transaction, including on error.
      guard.close();
    }
  }

  /// The installation-stable id of one seed reference and environment.
  ///
  /// It uses its own short-lived connection so callers outside [locked] can
  /// resolve ids without contending with the guard. It never creates,
  /// initializes or migrates the owner database: null means the foreground has
  /// not prepared it yet.
  Future<String?> groupId(String reference, String environment) async {
    if (!File(path).existsSync()) return null;
    final state = sqlite3.open(path, mode: OpenMode.readWrite);
    try {
      state.execute('PRAGMA busy_timeout = 3000');
      if (state.userVersion != schemaVersion) return null;
      final key = [reference, environment];
      state.execute('''
        INSERT INTO group_ids (secret_ref, environment, group_id)
        VALUES (?, ?, lower(hex(randomblob(16))))
        ON CONFLICT (secret_ref, environment) DO NOTHING
      ''', key);
      return state.select('''
        SELECT group_id FROM group_ids
        WHERE secret_ref = ? AND environment = ?
      ''', key).single['group_id']
          as String;
    } finally {
      state.close();
    }
  }

  void _requireOwned() {
    if (!File(path).existsSync()) throw const BackupMetadataStoreNotReady();
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
        id INTEGER PRIMARY KEY CHECK (id = 1), destination TEXT, account TEXT,
        generation INTEGER NOT NULL, lineage TEXT NOT NULL
      );
      CREATE TABLE included_groups (id TEXT PRIMARY KEY);
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
        secret_ref TEXT NOT NULL, environment TEXT NOT NULL,
        group_id TEXT NOT NULL UNIQUE, PRIMARY KEY (secret_ref, environment)
      );
    ''');
    state.execute('INSERT INTO selection VALUES (1, NULL, NULL, 0, ?)', [
      randomHex(16),
    ]);
  }
}

/// The owner database is absent or not at the foreground's current schema.
/// Headless callers translate it into a deferred run.
final class BackupMetadataStoreNotReady implements Exception {
  const BackupMetadataStoreNotReady();
}

/// State operations scoped to a held guard. Each operation is committed before
/// control returns to the caller.
final class BackupMetadataState {
  static const _scope =
      'destination = ? AND account = ? AND group_id = ? AND lineage = ? AND generation = ?';

  final Database _db;

  BackupMetadataState._(this._db);

  BackupSelection get selection {
    final row = _db.select('SELECT * FROM selection').single;
    final destination = row['destination'] as String?;
    return (
      destination: destination == null
          ? null
          : BackupDestination.values.byName(destination),
      account: row['account'] as String?,
      generation: row['generation'] as int,
      lineage: row['lineage'] as String,
      groups: {
        for (final group in _db.select('SELECT id FROM included_groups'))
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
        'UPDATE selection SET destination = ?, account = ?, generation = ?',
        [destination?.name, account, previous.generation + (changed ? 1 : 0)],
      );
      _db.execute('DELETE FROM included_groups');
      for (final group in groups) {
        _db.execute('INSERT INTO included_groups VALUES (?)', [group]);
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
