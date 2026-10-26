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
  static const _schemaVersion = 1;
  static const _maxPlatformId = 0x7fffffff;

  SqliteNotificationOutbox({
    required this.databasePath,
    this.claimLease = const Duration(minutes: 5),
  }) {
    Directory(File(databasePath).parent.path).createSync(recursive: true);
    final database = sqlite3.open(databasePath);
    try {
      _database = database;
      _database.execute('PRAGMA busy_timeout = 250');
      final version =
          (_database.select('PRAGMA user_version').single['user_version']
              as int);
      if (version > _schemaVersion) {
        throw StateError('Unsupported notification schema');
      }
      _database.execute('''
      CREATE TABLE IF NOT EXISTS notification_outbox (
        event_id TEXT PRIMARY KEY, title TEXT NOT NULL, body TEXT NOT NULL,
        destination TEXT NOT NULL, created_at INTEGER NOT NULL,
        status TEXT NOT NULL CHECK(status IN ('pending','delivering','delivered')),
        claim_token TEXT, lease_until INTEGER, platform_id INTEGER NOT NULL UNIQUE,
        topic_id TEXT
      )
    ''');
      _database.execute('PRAGMA user_version = 1');
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
    } catch (_) {
      database.dispose();
      rethrow;
    }
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
      final initialized = _database.select(
        'SELECT topic_id FROM notification_topics WHERE topic_id=?',
        [topicId],
      ).isNotEmpty;
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
            initialized ? 'pending' : 'delivered',
            platformId,
            topicId,
          ],
        );
        if (initialized) pendingCount++;
      }
      if (!initialized) {
        _database.execute(
          'INSERT INTO notification_topics(topic_id,initialized_at) VALUES (?,?)',
          [topicId, DateTime.now().toUtc().millisecondsSinceEpoch],
        );
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
      for (final observation in observations) {
        final initialized = _database.select(
          'SELECT topic_id FROM notification_topics WHERE topic_id=?',
          [observation.topicId],
        ).isNotEmpty;
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
          if (initialized) newlyObserved.add(event);
        }
        if (!initialized) {
          _database.execute(
            'INSERT INTO notification_topics(topic_id,initialized_at) VALUES (?,?)',
            [
              observation.topicId,
              DateTime.now().toUtc().millisecondsSinceEpoch,
            ],
          );
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
        }
      }
      _database.execute('COMMIT');
      return Ok(
        NotificationReconcileResult(
          pendingCount: newlyObserved.isNotEmpty ? 1 : 0,
        ),
      );
    } catch (_) {
      try {
        _database.execute('ROLLBACK');
      } catch (_) {}
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
