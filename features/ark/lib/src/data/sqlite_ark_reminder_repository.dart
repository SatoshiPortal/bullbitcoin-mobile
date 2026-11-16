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
/// but before commit safely re-applies the same id on the next observation.
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

  static Result<SqliteArkReminderRepository, ArkFailure> open({
    required String path,
    required ScheduledNotificationPort notifications,
    required String title,
    required String body,
    required bool foreground,
  }) {
    Database? opened;
    try {
      if (!foreground && !File(path).existsSync()) {
        return const Err(ArkFeatureStorageFailure());
      }
      final db = sqlite3.open(
        path,
        mode: foreground ? OpenMode.readWriteCreate : OpenMode.readWrite,
      );
      opened = db;
      db.execute('PRAGMA busy_timeout = 0');
      final version = db.userVersion;
      if (version == 0 && foreground) {
        db.execute('BEGIN IMMEDIATE');
        try {
          db.execute(
            'CREATE TABLE IF NOT EXISTS ark_reminders (account TEXT PRIMARY KEY, platform_id INTEGER NOT NULL UNIQUE CHECK(platform_id<0), revision INTEGER NOT NULL, tip INTEGER NOT NULL, signature TEXT, scheduled_at INTEGER)',
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
        final previousAt = row?['scheduled_at'] as int?;
        at = row?['signature'] == signature && previousAt != null
            ? DateTime.fromMicrosecondsSinceEpoch(previousAt, isUtc: true)
            : warning.notifyAt;
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
        'INSERT INTO ark_reminders(account,platform_id,revision,tip,signature,scheduled_at) VALUES(?,?,?,?,?,?) ON CONFLICT(account) DO UPDATE SET revision=excluded.revision,tip=excluded.tip,signature=excluded.signature,scheduled_at=excluded.scheduled_at',
        [
          account.canonical,
          platformId,
          revision,
          tipHeight,
          signature,
          at?.microsecondsSinceEpoch,
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

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _active?.future;
    _db.close();
  }
}
