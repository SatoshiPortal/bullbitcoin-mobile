import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ark/ark.dart';
import 'package:crypto/crypto.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import '../domain/ark_failure.dart';
import '../domain/ark_expiry_warning.dart';
import '../domain/repositories/ark_reminder_repository.dart';

/// A separate durable reminder ledger. Negative platform IDs cannot collide
/// with the payment outbox's positive IDs. BEGIN IMMEDIATE serializes platform
/// side effects across foreground/background engines. A crash after scheduling
/// but before commit remains a known lifecycle gap pending durable intent.
final class SqliteArkReminderRepository implements ArkReminderRepository {
  final Database _db;
  final ScheduledNotificationPort _notifications;
  final String title;
  final String body;
  bool _closed = false;
  Completer<void>? _active;
  SqliteArkReminderRepository._(
    this._db,
    this._notifications, {
    required this.title,
    required this.body,
  });

  /// Ordinary startup, including foreground, is existing-only. Set
  /// initializeNew only when the host has established this is first setup;
  /// it never overrides an initialized marker whose metadata disappeared.
  static Result<SqliteArkReminderRepository, ArkFailure> open({
    required String path,
    required ScheduledNotificationPort notifications,
    required String title,
    required String body,
    required bool foreground,
    bool initializeNew = false,
  }) {
    Database? opened;
    try {
      final databaseExists = File(path).existsSync();
      final marker = File('$path.initialized');
      final markerExists = marker.existsSync();
      if ((markerExists &&
              (!databaseExists ||
                  marker.readAsStringSync() != 'ark-reminders:1\n')) ||
          (!markerExists && (!foreground || !initializeNew))) {
        return const Err(ArkFeatureStorageFailure());
      }
      final db = sqlite3.open(
        path,
        mode: foreground ? OpenMode.readWriteCreate : OpenMode.readWrite,
      );
      opened = db;
      db.execute('PRAGMA busy_timeout = 0');
      final version = db.userVersion;
      if (version == 0 && foreground && initializeNew && !markerExists) {
        if (db
            .select(
              "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
            )
            .isNotEmpty) {
          db.close();
          opened = null;
          return const Err(ArkFeatureStorageFailure());
        }
        db.execute('BEGIN IMMEDIATE');
        try {
          db.execute(
            'CREATE TABLE IF NOT EXISTS ark_reminders (account TEXT PRIMARY KEY, platform_id INTEGER NOT NULL UNIQUE CHECK(platform_id<0), revision INTEGER NOT NULL, tip INTEGER NOT NULL, signature TEXT, scheduled_at INTEGER, deadline_bounds TEXT)',
          );
          db.userVersion = 1;
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      } else if (version != 1) {
        db.close();
        opened = null;
        return const Err(ArkFeatureStorageFailure());
      }
      db.select('SELECT deadline_bounds FROM ark_reminders LIMIT 0');
      if (!markerExists) {
        marker.writeAsStringSync('ark-reminders:1\n', flush: true);
      }
      return Ok(
        SqliteArkReminderRepository._(
          db,
          notifications,
          title: title,
          body: body,
        ),
      );
    } on Exception catch (_) {
      opened?.close();
      return const Err(ArkFeatureStorageFailure());
    }
  }

  @override
  Future<Result<void, ArkFailure>> reconcile({
    required ArkAccountId account,
    required ArkExpiryWarning? warning,
    required bool authoritativeEmpty,
    required int revision,
    required int tipHeight,
  }) async {
    if (_closed) return const Err(ArkFeatureStorageFailure());
    if (_active != null) return const Err(ArkOperationBusyFailure());
    if (warning == null && !authoritativeEmpty) return const Ok(null);
    final settled = Completer<void>();
    _active = settled;
    var admitted = false;
    try {
      _db.execute('BEGIN IMMEDIATE');
      admitted = true;
      final rows = _db.select('SELECT * FROM ark_reminders WHERE account=?', [
        account.canonical,
      ]);
      final row = rows.isEmpty ? null : rows.single;
      if (row != null &&
          (revision < (row['revision'] as int) ||
              tipHeight < (row['tip'] as int))) {
        _db.execute('COMMIT');
        admitted = false;
        return const Ok(null);
      }
      final int platformId;
      if (row != null) {
        platformId = row['platform_id'] as int;
      } else {
        platformId =
            (_db
                    .select(
                      'SELECT COALESCE(MIN(platform_id),0)-1 AS next FROM ark_reminders',
                    )
                    .single['next']
                as int);
        if (platformId < -2147483647) {
          _db.execute('ROLLBACK');
          admitted = false;
          return const Err(ArkFeatureStorageFailure());
        }
      }
      String? signature;
      String? boundsJson;
      DateTime? at;
      Result<void, NotificationsFailure> changed;
      if (warning != null) {
        final entries = warning.expiries.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        signature = sha256
            .convert(
              utf8.encode(
                jsonEncode({for (final e in entries) e.key: e.value}),
              ),
            )
            .toString();
        final deadlines = <String, int>{
          for (final entry in warning.deadlines.entries)
            _keyHash(entry.key): entry.value.microsecondsSinceEpoch,
        };
        if (row?['signature'] != null) {
          final previous = _readBounds(row?['deadline_bounds']);
          if (previous == null) return const Err(ArkFeatureStorageFailure());
          final retired = warning.retiredKeys.map(_keyHash).toSet();
          for (final entry in previous.entries) {
            if (retired.contains(entry.key)) continue;
            final current = deadlines[entry.key];
            if (current == null || entry.value < current) {
              deadlines[entry.key] = entry.value;
            }
          }
        }
        final earliest = deadlines.values.reduce((a, b) => a < b ? a : b);
        at = DateTime.fromMicrosecondsSinceEpoch(earliest, isUtc: true);
        boundsJson = jsonEncode(deadlines);
        changed = await _notifications.schedule(
          LocalNotification(
            eventId: 'ark-expiry',
            title: title,
            body: body,
            createdAt: DateTime.now(),
          ),
          platformId: platformId,
          at: at,
        );
      } else {
        changed = await _notifications.cancelScheduled(platformId);
      }
      if (changed is Err) {
        _db.execute('ROLLBACK');
        admitted = false;
        return const Err(ArkReminderUnavailableFailure());
      }
      _db.execute(
        'INSERT INTO ark_reminders(account,platform_id,revision,tip,signature,scheduled_at,deadline_bounds) VALUES(?,?,?,?,?,?,?) ON CONFLICT(account) DO UPDATE SET revision=excluded.revision,tip=excluded.tip,signature=excluded.signature,scheduled_at=excluded.scheduled_at,deadline_bounds=excluded.deadline_bounds',
        [
          account.canonical,
          platformId,
          revision,
          tipHeight,
          signature,
          at?.microsecondsSinceEpoch,
          boundsJson,
        ],
      );
      _db.execute('COMMIT');
      admitted = false;
      return const Ok(null);
    } on Exception catch (_) {
      return const Err(ArkFeatureStorageFailure());
    } finally {
      try {
        if (admitted) {
          _db.execute('ROLLBACK');
        }
      } finally {
        _active = null;
        settled.complete();
      }
    }
  }

  static String _keyHash(String key) =>
      sha256.convert(utf8.encode(key)).toString();
  static Map<String, int>? _readBounds(Object? encoded) {
    if (encoded is! String) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic> || decoded.isEmpty) return null;
    final result = <String, int>{};
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(entry.key) ||
          value is! int ||
          value.abs() > 8640000000000000000) {
        return null;
      }
      result[entry.key] = value;
    }
    return result;
  }

  /// Startup must restore previously admitted alarms even while offline or
  /// before a fresh native pass. Reapply uses persisted deadlines/IDs only and
  /// cannot clear a warning or postpone an expiry from a cached observation.
  Future<Result<void, ArkFailure>> reapplyStored() async {
    if (_closed) return const Err(ArkFeatureStorageFailure());
    if (_active != null) return const Err(ArkOperationBusyFailure());
    final settled = Completer<void>();
    _active = settled;
    var admitted = false;
    try {
      _db.execute('BEGIN IMMEDIATE');
      admitted = true;
      for (final row in _db.select(
        'SELECT platform_id,scheduled_at FROM ark_reminders WHERE signature IS NOT NULL',
      )) {
        final at = row['scheduled_at'];
        final id = row['platform_id'];
        if (at is! int || id is! int) {
          return const Err(ArkFeatureStorageFailure());
        }
        final result = await _notifications.schedule(
          LocalNotification(
            eventId: 'ark-expiry',
            title: title,
            body: body,
            createdAt: DateTime.now(),
          ),
          platformId: id,
          at: DateTime.fromMicrosecondsSinceEpoch(at, isUtc: true),
        );
        if (result is Err) return const Err(ArkReminderUnavailableFailure());
      }
      _db.execute('COMMIT');
      admitted = false;
      return const Ok(null);
    } on Exception catch (_) {
      return const Err(ArkFeatureStorageFailure());
    } finally {
      try {
        if (admitted) _db.execute('ROLLBACK');
      } finally {
        _active = null;
        settled.complete();
      }
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _active?.future;
    _db.close();
  }
}
