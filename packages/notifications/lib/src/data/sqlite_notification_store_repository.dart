import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import '../domain/local_notification.dart';
import '../domain/notifications_failure.dart';
import '../domain/observation.dart';
import '../domain/repositories/notification_store_repository.dart';

/// The notification store: observed payment identities per topic, and the
/// aggregates waiting to be shown. Both transactions that matter, observation
/// plus aggregate and delivery claim, are in this file.
final class SqliteNotificationStoreRepository
    implements NotificationStoreRepository {
  /// Unpublished: a single CREATE, no migration.
  static const schemaVersion = 1;

  /// Platform IDs are positive 31-bit integers, allocated once each.
  static const maxPlatformId = 0x7fffffff;

  /// Rows per INSERT, far below SQLite's bound on statement parameters.
  static const _batchSize = 200;

  final Database _database;
  final Duration claimLease;
  bool _closed = false;

  SqliteNotificationStoreRepository._(this._database, this.claimLease);

  /// Foreground only: creates the store on first use, or checks its version.
  static Result<SqliteNotificationStoreRepository, NotificationsFailure>
  openForeground(
    String path, {
    Duration claimLease = const Duration(minutes: 5),
  }) => _open(path, create: true).map(
    (database) => SqliteNotificationStoreRepository._(database, claimLease),
  );

  /// Background: opens a store the foreground created, never creating or
  /// migrating one. An absent, older or newer store is refused.
  static Result<SqliteNotificationStoreRepository, NotificationsFailure>
  openExisting(
    String path, {
    Duration claimLease = const Duration(minutes: 5),
  }) => _open(path, create: false).map(
    (database) => SqliteNotificationStoreRepository._(database, claimLease),
  );

  static Result<Database, NotificationsFailure> _open(
    String path, {
    required bool create,
  }) {
    final Database database;
    try {
      if (create) Directory(File(path).parent.path).createSync(recursive: true);
      // Without the create flag, opening a missing file fails here.
      database = sqlite3.open(
        path,
        mode: create ? OpenMode.readWriteCreate : OpenMode.readWrite,
      );
    } on Exception {
      return const Err(NotificationsStoreUnavailableFailure());
    }
    try {
      database.execute('PRAGMA busy_timeout = 5000');
      // One transaction: the version read and the creation cannot race
      // another connection opening the same new file.
      database.execute('BEGIN IMMEDIATE');
      final version =
          database.select('PRAGMA user_version').single['user_version'] as int;
      final empty = database.select('SELECT 1 FROM sqlite_master').isEmpty;
      if (create && version == 0 && empty) {
        _create(database);
      } else if (version != schemaVersion) {
        database.execute('ROLLBACK');
        database.dispose();
        return Err(NotificationsStoreVersionFailure(version));
      }
      database.execute('COMMIT');
      return Ok(database);
    } on SqliteException {
      _rollback(database);
      database.dispose();
      return const Err(NotificationsStorageFailure());
    }
  }

  static void _create(Database database) {
    database.execute('''
      CREATE TABLE topics (
        topic_id TEXT PRIMARY KEY,
        initialized_at INTEGER NOT NULL
      )''');
    database.execute('''
      CREATE TABLE observed_events (
        topic_id TEXT NOT NULL,
        event_id TEXT NOT NULL,
        PRIMARY KEY (topic_id, event_id)
      )''');
    database.execute('''
      CREATE TABLE outbox (
        event_id TEXT PRIMARY KEY,
        topic_id TEXT NOT NULL,
        platform_id INTEGER NOT NULL UNIQUE,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        state TEXT NOT NULL CHECK (state IN ('pending', 'delivering')),
        claim_token TEXT,
        claimed_until INTEGER
      )''');
    // One row: the next platform ID. It only grows, so a delivered
    // notification still on screen is never replaced by a new one.
    database.execute('''
      CREATE TABLE platform_ids (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        next_id INTEGER NOT NULL
      )''');
    database.execute('INSERT INTO platform_ids (id, next_id) VALUES (1, 1)');
    database.execute('PRAGMA user_version = $schemaVersion');
  }

  @override
  Future<Result<void, NotificationsFailure>> recordForeground(
    Observation observation,
  ) async => _transaction(() {
    // The first complete foreground observation initializes the topic, even
    // with no event: its history is a silent baseline. Later ones only add
    // the events they see, so the app never announces what it showed.
    _insertEvents(observation);
    _database.execute(
      'INSERT OR IGNORE INTO topics (topic_id, initialized_at) VALUES (?, ?)',
      [observation.topicId, _nowMs()],
    );
    // Rule P, awaiting Azad's decision. Today a pending aggregate stays until
    // it is delivered. Option P1 would add, here and in this transaction:
    //   DELETE FROM outbox WHERE topic_id = ? AND state = 'pending'
  });

  @override
  Future<Result<BackgroundObservation, NotificationsFailure>> recordBackground(
    Observation observation,
    LocalNotification Function(List<String> newEventIds) aggregate,
  ) async => _transaction(() {
    final initialized = _database.select(
      'SELECT 1 FROM topics WHERE topic_id = ?',
      [observation.topicId],
    );
    // Never a baseline taken behind the user's back.
    if (initialized.isEmpty) return BackgroundObservation.topicNotInitialized;
    final inserted = _insertEvents(observation);
    if (inserted.isEmpty) return BackgroundObservation.nothingNew;
    final notification = aggregate(List.unmodifiable(inserted));
    _database.execute(
      '''INSERT INTO outbox
         (event_id, topic_id, platform_id, title, body, created_at, state)
         VALUES (?, ?, ?, ?, ?, ?, 'pending')''',
      [
        notification.eventId,
        observation.topicId,
        _allocatePlatformId(),
        notification.title,
        notification.body,
        notification.createdAt.toUtc().millisecondsSinceEpoch,
      ],
    );
    return BackgroundObservation.enqueued;
  });

  /// Inserts the observed events in bounded batches and returns those that
  /// were not stored yet, in observation order.
  List<String> _insertEvents(Observation observation) {
    final ids = observation.eventIds.toList();
    final inserted = <String>{};
    for (var start = 0; start < ids.length; start += _batchSize) {
      final batch = ids.sublist(start, min(start + _batchSize, ids.length));
      final rows = _database.select(
        'INSERT OR IGNORE INTO observed_events (topic_id, event_id) VALUES '
        '${List.filled(batch.length, '(?, ?)').join(', ')} RETURNING event_id',
        [
          for (final id in batch) ...[observation.topicId, id],
        ],
      );
      inserted.addAll(rows.map((row) => row['event_id'] as String));
    }
    return [
      for (final id in ids)
        if (inserted.contains(id)) id,
    ];
  }

  int _allocatePlatformId() {
    final next =
        _database
                .select('SELECT next_id FROM platform_ids WHERE id = 1')
                .single['next_id']
            as int;
    if (next > maxPlatformId) {
      throw const _Refused(NotificationsPlatformIdsExhaustedFailure());
    }
    _database.execute('UPDATE platform_ids SET next_id = ? WHERE id = 1', [
      next + 1,
    ]);
    return next;
  }

  @override
  Future<Result<ClaimedNotification?, NotificationsFailure>> claimNext({
    DateTime? now,
  }) async => _transaction(() {
    final current = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    final rows = _database.select(
      '''SELECT event_id, platform_id, title, body, created_at FROM outbox
         WHERE state = 'pending'
            OR (state = 'delivering' AND claimed_until <= ?)
         ORDER BY created_at, event_id LIMIT 1''',
      [current],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    final token = _claimToken();
    _database.execute(
      '''UPDATE outbox SET state = 'delivering', claim_token = ?,
         claimed_until = ? WHERE event_id = ?''',
      [token, current + claimLease.inMilliseconds, row['event_id']],
    );
    return ClaimedNotification(
      claimToken: token,
      platformId: row['platform_id'] as int,
      notification: LocalNotification(
        eventId: row['event_id'] as String,
        title: row['title'] as String,
        body: row['body'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['created_at'] as int,
          isUtc: true,
        ),
      ),
    );
  });

  @override
  Future<Result<void, NotificationsFailure>> settle(
    ClaimedNotification claim,
  ) async => _byClaim(
    'DELETE FROM outbox WHERE event_id = ? AND claim_token = ?',
    claim,
  );

  @override
  Future<Result<void, NotificationsFailure>> release(
    ClaimedNotification claim,
  ) async =>
      _byClaim('''UPDATE outbox SET state = 'pending', claim_token = NULL,
       claimed_until = NULL WHERE event_id = ? AND claim_token = ?''', claim);

  /// A claim taken over after its lease expired no longer matches its token.
  Result<void, NotificationsFailure> _byClaim(
    String sql,
    ClaimedNotification claim,
  ) {
    try {
      _database.execute(sql, [claim.notification.eventId, claim.claimToken]);
      return _database.updatedRows == 1
          ? const Ok(null)
          : const Err(NotificationsClaimLostFailure());
    } on SqliteException {
      return const Err(NotificationsStorageFailure());
    }
  }

  Result<T, NotificationsFailure> _transaction<T>(T Function() body) {
    try {
      _database.execute('BEGIN IMMEDIATE');
    } on SqliteException {
      return const Err(NotificationsStorageFailure());
    }
    try {
      final value = body();
      _database.execute('COMMIT');
      return Ok(value);
    } on SqliteException {
      _rollback(_database);
      return const Err(NotificationsStorageFailure());
    } on _Refused catch (refused) {
      _rollback(_database);
      return Err(refused.failure);
    } catch (_) {
      // A programming error, for instance in the aggregate callback.
      _rollback(_database);
      rethrow;
    }
  }

  static void _rollback(Database database) {
    try {
      database.execute('ROLLBACK');
    } on SqliteException {
      // Nothing is open.
    }
  }

  static int _nowMs() => DateTime.now().toUtc().millisecondsSinceEpoch;

  static String _claimToken() {
    final random = Random.secure();
    return base64UrlEncode(List.generate(24, (_) => random.nextInt(256)));
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _database.dispose();
  }
}

final class _Refused implements Exception {
  final NotificationsFailure failure;
  const _Refused(this.failure);
}

/// Phase A contact: lib/features/wallet still opens the store through this
/// name, creating it like [SqliteNotificationStoreRepository.openForeground].
/// Phase B moves the feature to the two named openings and deletes this class.
final class SqliteNotificationOutbox extends SqliteNotificationStoreRepository {
  SqliteNotificationOutbox({required String databasePath})
    : super._(switch (SqliteNotificationStoreRepository._open(
        databasePath,
        create: true,
      )) {
        Ok(:final value) => value,
        Err(:final failure) => throw _Refused(failure),
      }, const Duration(minutes: 5));

  Future<void> dispose() => close();
}
