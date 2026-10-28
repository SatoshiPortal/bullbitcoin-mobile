import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import '../domain/local_notification.dart';
import '../domain/notification_destination.dart';
import '../domain/notification_outbox_port.dart';
import '../domain/notification_reconcile_result.dart';
import '../domain/notifications_failure.dart';

final class SqliteNotificationOutbox implements NotificationOutboxPort {
  final String databasePath;
  late final Database _database;
  final Duration claimLease;
  static const _schemaVersion = 2;
  static const _maxPlatformId = 0x7fffffff;

  SqliteNotificationOutbox({
    required this.databasePath,
    this.claimLease = const Duration(minutes: 5),
  }) {
    Directory(File(databasePath).parent.path).createSync(recursive: true);
    final database = sqlite3.open(databasePath);
    try {
      _database = database;
      // The foreground keeps its outbox open for the process lifetime while
      // a background run writes to the same file.
      _database.execute('PRAGMA busy_timeout = 5000');
      // One transaction: an app and a background engine opening an old file
      // at once must not both upgrade it.
      _database.execute('BEGIN IMMEDIATE');
      try {
        _migrate();
        _database.execute('COMMIT');
      } catch (_) {
        _database.execute('ROLLBACK');
        rethrow;
      }
    } catch (_) {
      database.dispose();
      rethrow;
    }
  }

  void _migrate() {
    final version =
        _database.select('PRAGMA user_version').single['user_version'] as int;
    if (version > _schemaVersion) {
      throw StateError('Unsupported notification schema');
    }
    _database.execute('''
      CREATE TABLE IF NOT EXISTS notification_outbox (
        event_id TEXT PRIMARY KEY, title TEXT NOT NULL, body TEXT NOT NULL,
        destination TEXT NOT NULL, created_at INTEGER NOT NULL,
        status TEXT NOT NULL CHECK(status IN ('pending','delivering','delivered')),
        claim_token TEXT, lease_until INTEGER, platform_id INTEGER NOT NULL UNIQUE,
        topic_id TEXT, seen_at INTEGER
      )
    ''');
    _database.execute('''
      CREATE TABLE IF NOT EXISTS notification_responses (
        id INTEGER PRIMARY KEY AUTOINCREMENT, payload TEXT NOT NULL,
        consumed INTEGER NOT NULL DEFAULT 0
      )
    ''');
    _database.execute('''
      CREATE TABLE IF NOT EXISTS notification_topics (
        topic_id TEXT PRIMARY KEY, initialized_at INTEGER NOT NULL
      )
    ''');
    _database.execute('''
      CREATE TABLE IF NOT EXISTS notification_aggregate_members (
        aggregate_event_id TEXT NOT NULL, member_event_id TEXT NOT NULL,
        PRIMARY KEY (aggregate_event_id, member_event_id)
      )
    ''');
    // Checked whatever the version: an older open interrupted after creating
    // the table could leave it without the column at version 0.
    final columns = _database
        .select('PRAGMA table_info(notification_outbox)')
        .map((row) => row['name'] as String)
        .toSet();
    if (!columns.contains('seen_at')) {
      _database.execute(
        'ALTER TABLE notification_outbox ADD COLUMN seen_at INTEGER',
      );
    }
    if (version == 1) {
      // Version 1 initialized a topic with a silent background baseline and
      // kept no aggregate members: neither can be trusted any more, so the
      // foreground records topics again and old aggregates are settled.
      _database.execute('DELETE FROM notification_topics');
      _database.execute(
        "UPDATE notification_outbox SET status='delivered', claim_token=NULL, lease_until=NULL WHERE topic_id IS NULL AND status!='delivered'",
      );
    }
    _database.execute('PRAGMA user_version = $_schemaVersion');
  }

  @override
  Future<Result<void, NotificationsFailure>> enqueue(
    LocalNotification event,
  ) async {
    try {
      _database.execute('BEGIN IMMEDIATE');
      final existing = _database.select(
        'SELECT event_id FROM notification_outbox WHERE event_id=?',
        [event.eventId],
      );
      if (existing.isEmpty) {
        final platformId = _allocatePlatformId(event.eventId);
        _database.execute(
          '''INSERT INTO notification_outbox
          (event_id,title,body,destination,created_at,status,platform_id)
          VALUES (?,?,?,?,?,'pending',?)''',
          [
            event.eventId,
            event.title,
            event.body,
            event.destination.wireValue,
            event.createdAt.toUtc().millisecondsSinceEpoch,
            platformId,
          ],
        );
      }
      _database.execute('COMMIT');
      return const Ok(null);
    } catch (_) {
      try {
        _database.execute('ROLLBACK');
      } catch (_) {}
      return const Err(NotificationsStorageFailure());
    }
  }

  @override
  Future<Result<NotificationReconcileResult, NotificationsFailure>>
  reconcileTopic(String topicId, List<LocalNotification> observedEvents) async {
    try {
      _database.execute('BEGIN IMMEDIATE');
      if (!_isInitialized(topicId)) {
        _database.execute('COMMIT');
        return const Ok(
          NotificationReconcileResult(pendingCount: 0, skippedTopicCount: 1),
        );
      }
      var pendingCount = 0;
      final observedIds = <String>{};
      for (final event in observedEvents) {
        if (!observedIds.add(event.eventId)) continue;
        final existing = _database.select(
          'SELECT event_id FROM notification_outbox WHERE event_id=?',
          [event.eventId],
        );
        if (existing.isNotEmpty) continue;
        final platformId = _allocatePlatformId(event.eventId);
        _database.execute(
          '''INSERT INTO notification_outbox
          (event_id,title,body,destination,created_at,status,platform_id,topic_id)
          VALUES (?,?,?,?,?,?,?,?)''',
          [
            event.eventId,
            event.title,
            event.body,
            event.destination.wireValue,
            event.createdAt.toUtc().millisecondsSinceEpoch,
            'pending',
            platformId,
            topicId,
          ],
        );
        pendingCount++;
      }
      _database.execute('COMMIT');
      return Ok(NotificationReconcileResult(pendingCount: pendingCount));
    } catch (_) {
      try {
        _database.execute('ROLLBACK');
      } catch (_) {}
      return const Err(NotificationsStorageFailure());
    }
  }

  @override
  Future<Result<NotificationReconcileResult, NotificationsFailure>>
  reconcileTopicsAndEnqueue(
    List<NotificationTopicObservation> observations,
    LocalNotification Function(List<LocalNotification> newEvents)
    aggregateEvent,
  ) async {
    try {
      _database.execute('BEGIN IMMEDIATE');
      final newlyObserved = <LocalNotification>[];
      var skippedTopicCount = 0;
      for (final observation in observations) {
        if (!_isInitialized(observation.topicId)) {
          skippedTopicCount++;
          continue;
        }
        final observedIds = <String>{};
        for (final event in observation.observedEvents) {
          if (!observedIds.add(event.eventId)) continue;
          final existing = _database.select(
            'SELECT event_id FROM notification_outbox WHERE event_id=?',
            [event.eventId],
          );
          if (existing.isNotEmpty) continue;
          final platformId = _allocatePlatformId(event.eventId);
          _database.execute(
            '''INSERT INTO notification_outbox
            (event_id,title,body,destination,created_at,status,platform_id,topic_id)
            VALUES (?,?,?,?,?,'delivered',?,?)''',
            [
              event.eventId,
              event.title,
              event.body,
              event.destination.wireValue,
              event.createdAt.toUtc().millisecondsSinceEpoch,
              platformId,
              observation.topicId,
            ],
          );
          newlyObserved.add(event);
        }
      }
      if (newlyObserved.isNotEmpty) {
        final event = aggregateEvent(List.unmodifiable(newlyObserved));
        final existing = _database.select(
          'SELECT event_id FROM notification_outbox WHERE event_id=?',
          [event.eventId],
        );
        if (existing.isEmpty) {
          final platformId = _allocatePlatformId(event.eventId);
          _database.execute(
            '''INSERT INTO notification_outbox
            (event_id,title,body,destination,created_at,status,platform_id)
            VALUES (?,?,?,?,?,'pending',?)''',
            [
              event.eventId,
              event.title,
              event.body,
              event.destination.wireValue,
              event.createdAt.toUtc().millisecondsSinceEpoch,
              platformId,
            ],
          );
          for (final member in newlyObserved) {
            _database.execute(
              '''INSERT OR IGNORE INTO notification_aggregate_members
              (aggregate_event_id, member_event_id) VALUES (?,?)''',
              [event.eventId, member.eventId],
            );
          }
        }
      }
      _database.execute('COMMIT');
      return Ok(
        NotificationReconcileResult(
          pendingCount: newlyObserved.isNotEmpty ? 1 : 0,
          skippedTopicCount: skippedTopicCount,
        ),
      );
    } catch (_) {
      try {
        _database.execute('ROLLBACK');
      } catch (_) {}
      return const Err(NotificationsStorageFailure());
    }
  }

  bool _isInitialized(String topicId) => _database.select(
    'SELECT topic_id FROM notification_topics WHERE topic_id=?',
    [topicId],
  ).isNotEmpty;

  @override
  Future<Result<bool, NotificationsFailure>> isTopicInitialized(
    String topicId,
  ) async {
    try {
      return Ok(_isInitialized(topicId));
    } catch (_) {
      return const Err(NotificationsStorageFailure());
    }
  }

  @override
  Future<Result<void, NotificationsFailure>> recordObserved(
    String topicId,
    List<LocalNotification> observedEvents,
  ) async {
    try {
      _database.execute('BEGIN IMMEDIATE');
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final observedIds = <String>{};
      for (final event in observedEvents) {
        if (!observedIds.add(event.eventId)) continue;
        final existing = _database.select(
          'SELECT event_id FROM notification_outbox WHERE event_id=?',
          [event.eventId],
        );
        if (existing.isNotEmpty) {
          _database.execute(
            'UPDATE notification_outbox SET seen_at=? WHERE event_id=? AND seen_at IS NULL',
            [now, event.eventId],
          );
          continue;
        }
        _database.execute(
          '''INSERT INTO notification_outbox
          (event_id,title,body,destination,created_at,status,platform_id,topic_id,seen_at)
          VALUES (?,?,?,?,?,'delivered',?,?,?)''',
          [
            event.eventId,
            event.title,
            event.body,
            event.destination.wireValue,
            event.createdAt.toUtc().millisecondsSinceEpoch,
            _allocatePlatformId(event.eventId),
            topicId,
            now,
          ],
        );
      }
      if (!_isInitialized(topicId)) {
        _database.execute(
          'INSERT INTO notification_topics(topic_id,initialized_at) VALUES (?,?)',
          [topicId, now],
        );
      }
      // A pending aggregate announces nothing new once every payment in it
      // has been seen.
      final stale = _database.select('''
        SELECT o.event_id FROM notification_outbox o
        WHERE o.status='pending'
          AND EXISTS (SELECT 1 FROM notification_aggregate_members m
                      WHERE m.aggregate_event_id=o.event_id)
          AND NOT EXISTS (
            SELECT 1 FROM notification_aggregate_members m
            JOIN notification_outbox e ON e.event_id=m.member_event_id
            WHERE m.aggregate_event_id=o.event_id AND e.seen_at IS NULL)
      ''');
      for (final row in stale) {
        final id = row['event_id'] as String;
        _database.execute(
          'DELETE FROM notification_aggregate_members WHERE aggregate_event_id=?',
          [id],
        );
        _database.execute('DELETE FROM notification_outbox WHERE event_id=?', [
          id,
        ]);
      }
      _database.execute('COMMIT');
      return const Ok(null);
    } catch (_) {
      try {
        _database.execute('ROLLBACK');
      } catch (_) {}
      return const Err(NotificationsStorageFailure());
    }
  }

  @override
  Future<Result<bool, NotificationsFailure>> isSeen(String eventId) async {
    try {
      final unseen = _database.select(
        '''
        SELECT 1 FROM notification_aggregate_members m
        LEFT JOIN notification_outbox e ON e.event_id=m.member_event_id
        WHERE m.aggregate_event_id=? AND (e.seen_at IS NULL)
        LIMIT 1''',
        [eventId],
      );
      final members = _database.select(
        'SELECT 1 FROM notification_aggregate_members WHERE aggregate_event_id=? LIMIT 1',
        [eventId],
      );
      return Ok(members.isNotEmpty && unseen.isEmpty);
    } catch (_) {
      return const Err(NotificationsStorageFailure());
    }
  }

  @override
  Future<Result<List<ClaimedNotification>, NotificationsFailure>> claimPending({
    DateTime? now,
  }) async {
    try {
      final events = <ClaimedNotification>[];
      final current = (now ?? DateTime.now()).toUtc();
      final leaseUntil = current.add(claimLease).millisecondsSinceEpoch;
      _database.execute('BEGIN IMMEDIATE');
      final rows = _database.select(
        "SELECT * FROM notification_outbox WHERE status='pending' OR (status='delivering' AND lease_until <= ?) ORDER BY created_at,event_id",
        [current.millisecondsSinceEpoch],
      );
      for (final row in rows) {
        final destination = NotificationDestination.fromWire(
          row['destination'] as String,
        );
        if (destination == null) continue;
        final token = _claimToken();
        _database.execute(
          "UPDATE notification_outbox SET status='delivering', claim_token=?, lease_until=? WHERE event_id=? AND (status='pending' OR (status='delivering' AND lease_until <= ?))",
          [token, leaseUntil, row['event_id'], current.millisecondsSinceEpoch],
        );
        events.add(
          ClaimedNotification(
            claimToken: token,
            platformId: row['platform_id'] as int,
            notification: LocalNotification(
              eventId: row['event_id'] as String,
              title: row['title'] as String,
              body: row['body'] as String,
              destination: destination,
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                row['created_at'] as int,
                isUtc: true,
              ),
            ),
          ),
        );
      }
      _database.execute('COMMIT');
      return Ok(List.unmodifiable(events));
    } catch (_) {
      try {
        _database.execute('ROLLBACK');
      } catch (_) {}
      return const Err(NotificationsStorageFailure());
    }
  }

  @override
  Future<Result<void, NotificationsFailure>> markDelivered(
    String eventId,
    String claimToken,
  ) async {
    return _updateStatus(eventId, claimToken, 'delivered');
  }

  @override
  Future<Result<void, NotificationsFailure>> release(
    String eventId,
    String claimToken,
  ) async {
    return _updateStatus(eventId, claimToken, 'pending');
  }

  Future<Result<void, NotificationsFailure>> _updateStatus(
    String eventId,
    String claimToken,
    String status,
  ) async {
    try {
      _database.execute(
        'UPDATE notification_outbox SET status=?, claim_token=NULL, lease_until=NULL WHERE event_id=? AND claim_token=?',
        [status, eventId, claimToken],
      );
      if (_database.updatedRows == 0) {
        return const Err(NotificationsClaimLostFailure());
      }
      return const Ok(null);
    } catch (_) {
      return const Err(NotificationsStorageFailure());
    }
  }

  @override
  Result<void, NotificationsFailure> persistResponse(String payload) {
    try {
      _database.execute(
        'INSERT INTO notification_responses(payload) VALUES (?)',
        [payload],
      );
      return const Ok(null);
    } catch (_) {
      return const Err(NotificationsStorageFailure());
    }
  }

  @override
  Future<Result<String?, NotificationsFailure>> consumeResponse() async {
    try {
      _database.execute('BEGIN IMMEDIATE');
      final rows = _database.select(
        'SELECT id,payload FROM notification_responses WHERE consumed=0 ORDER BY id LIMIT 1',
      );
      if (rows.isEmpty) {
        _database.execute('COMMIT');
        return const Ok(null);
      }
      final row = rows.single;
      _database.execute(
        'UPDATE notification_responses SET consumed=1 WHERE id=?',
        [row['id']],
      );
      _database.execute('COMMIT');
      return Ok(row['payload'] as String);
    } catch (_) {
      try {
        _database.execute('ROLLBACK');
      } catch (_) {}
      return const Err(NotificationsStorageFailure());
    }
  }

  void dispose() => _database.dispose();

  int _hashCandidate(String eventId) {
    final digest = sha256.convert(utf8.encode(eventId)).bytes;
    var candidate = 0;
    for (final byte in digest.take(4)) {
      candidate = (candidate << 8) | byte;
    }
    return candidate & _maxPlatformId;
  }

  int _allocatePlatformId(String eventId) {
    var platformId = _hashCandidate(eventId);
    while (_database.select(
      'SELECT platform_id FROM notification_outbox WHERE platform_id=?',
      [platformId],
    ).isNotEmpty) {
      platformId = (platformId + 1) & _maxPlatformId;
    }
    return platformId;
  }

  String _claimToken() =>
      '${Random.secure().nextInt(1 << 32)}-${DateTime.now().microsecondsSinceEpoch}';
}
