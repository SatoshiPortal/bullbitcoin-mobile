import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ark/ark.dart';
import 'package:crypto/crypto.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import 'ark_reminder_guard.dart';

import '../domain/ark_failure.dart';
import '../domain/ark_expiry_warning.dart';
import '../domain/repositories/ark_reminder_repository.dart';

/// A separate durable reminder ledger. Negative platform IDs cannot collide
/// with the payment outbox's positive IDs. A permanent sibling guard serializes
/// committed desired actions and their platform effects across all engines.
final class SqliteArkReminderRepository implements ArkReminderRepository {
  final Database _db;
  final ArkReminderGuard _guard;
  final ScheduledNotificationPort _notifications;
  final String title;
  final String body;
  bool _closed = false;
  Completer<void>? _active;
  SqliteArkReminderRepository._(
    this._db,
    this._guard,
    this._notifications, {
    required this.title,
    required this.body,
  });

  /// Ordinary startup, including foreground, is existing-only. Set
  /// initializeNew only when the host has established this is first setup;
  /// it never overrides an initialized marker whose metadata disappeared.
  /// migrateLegacy explicitly adopts a version-one publication in foreground;
  /// ordinary opens never create a missing guard behind an established marker.
  static Result<SqliteArkReminderRepository, ArkFailure> open({
    required String path,
    required ScheduledNotificationPort notifications,
    required String title,
    required String body,
    required bool foreground,
    bool initializeNew = false,
    bool migrateLegacy = false,
  }) {
    Database? opened;
    ArkReminderGuard? guard;
    try {
      // Canonical sibling paths prevent aliases from selecting another guard.
      final file = File(path);
      final name = file.uri.pathSegments.last;
      final canonical = '${file.parent.resolveSymbolicLinksSync()}/$name';
      final marker = File('$canonical.initialized');
      final guardFile = File('$canonical.guard');
      for (final entry in [canonical, marker.path, guardFile.path]) {
        if (FileSystemEntity.typeSync(entry, followLinks: false) ==
            FileSystemEntityType.link) {
          return const Err(ArkFeatureStorageFailure());
        }
      }
      final databaseExists = File(canonical).existsSync();
      final markerExists = marker.existsSync();
      final publication = markerExists ? marker.readAsStringSync() : null;
      final firstSetup = !markerExists && foreground && initializeNew;
      final legacy =
          publication == 'ark-reminders:1\n' &&
          foreground &&
          migrateLegacy &&
          databaseExists;
      if ((!firstSetup && !legacy && publication != 'ark-reminders:2\n') ||
          (markerExists && !databaseExists) ||
          (!firstSetup && !legacy && !guardFile.existsSync())) {
        return const Err(ArkFeatureStorageFailure());
      }
      final exclusion = ArkReminderGuard.open(
        guardFile.path,
        create: firstSetup || legacy,
      );
      guard = exclusion;
      final db = sqlite3.open(
        canonical,
        mode: firstSetup ? OpenMode.readWriteCreate : OpenMode.readWrite,
      );
      opened = db;
      db.execute('PRAGMA busy_timeout = 0');
      final version = db.userVersion;
      if (version == 0 && firstSetup) {
        if (db
            .select(
              "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
            )
            .isNotEmpty) {
          throw const FormatException('Unexpected reminder tables');
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
        throw const FormatException('Unexpected reminder version');
      }
      db.select(
        'SELECT account,platform_id,revision,tip,signature,scheduled_at,deadline_bounds FROM ark_reminders LIMIT 0',
      );
      for (final row in db.select('SELECT * FROM ark_reminders')) {
        _validateDesired(row);
      }
      if (db.select('PRAGMA quick_check').single.values.single != 'ok') {
        throw const FormatException('Invalid reminder ledger');
      }
      if (publication != 'ark-reminders:2\n') {
        marker.writeAsStringSync('ark-reminders:2\n', flush: true);
      }
      exclusion.release();
      return Ok(
        SqliteArkReminderRepository._(
          db,
          exclusion,
          notifications,
          title: title,
          body: body,
        ),
      );
    } on Exception catch (_) {
      opened?.close();
      guard?.close();
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
    var guarded = false;
    try {
      _guard.acquire();
      guarded = true;
      _db.execute('BEGIN IMMEDIATE');
      admitted = true;
      for (final existing in _db.select('SELECT * FROM ark_reminders')) {
        _validateDesired(existing);
      }
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
      return await _apply(platformId, at);
    } on Exception catch (_) {
      return const Err(ArkFeatureStorageFailure());
    } finally {
      try {
        if (admitted) {
          _db.execute('ROLLBACK');
        }
      } finally {
        try {
          if (guarded) _guard.release();
        } finally {
          _active = null;
          settled.complete();
        }
      }
    }
  }

  Future<Result<void, ArkFailure>> _apply(int id, DateTime? at) async {
    try {
      final result = at == null
          ? await _notifications.cancelScheduled(id)
          : await _notifications.schedule(
              LocalNotification(
                eventId: 'ark-expiry',
                title: title,
                body: body,
                createdAt: DateTime.now(),
              ),
              platformId: id,
              at: at,
            );
      return result.mapErr((_) => const ArkReminderUnavailableFailure());
    } on Exception catch (_) {
      return const Err(ArkReminderUnavailableFailure());
    }
  }

  static void _validateDesired(Row row) {
    final id = row['platform_id'];
    final revision = row['revision'];
    final tip = row['tip'];
    final at = row['scheduled_at'];
    final signature = row['signature'];
    final bounds = row['deadline_bounds'];
    final account = row['account'];
    if (account is! String ||
        account.isEmpty ||
        id is! int ||
        id >= 0 ||
        id < -2147483647 ||
        revision is! int ||
        revision < 0 ||
        tip is! int ||
        tip < 0) {
      throw const FormatException('Invalid reminder identity');
    }
    if (signature == null) {
      if (at != null || bounds != null) {
        throw const FormatException('Invalid reminder cancellation');
      }
    } else {
      final decoded = _readBounds(bounds);
      if (signature is! String ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(signature) ||
          at is! int ||
          decoded == null ||
          at != decoded.values.reduce((a, b) => a < b ? a : b)) {
        throw const FormatException('Invalid reminder schedule');
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
    var guarded = false;
    try {
      _guard.acquire();
      guarded = true;
      _db.execute('BEGIN IMMEDIATE');
      admitted = true;
      final desired = _db.select('SELECT * FROM ark_reminders');
      for (final row in desired) {
        _validateDesired(row);
      }
      _db.execute('COMMIT');
      admitted = false;
      for (final row in desired) {
        final id = row['platform_id'] as int;
        final at = row['scheduled_at'] as int?;
        final result = await _apply(
          id,
          at == null
              ? null
              : DateTime.fromMicrosecondsSinceEpoch(at, isUtc: true),
        );
        if (result is Err) return result;
      }
      return const Ok(null);
    } on Exception catch (_) {
      return const Err(ArkFeatureStorageFailure());
    } finally {
      try {
        if (admitted) _db.execute('ROLLBACK');
      } finally {
        try {
          if (guarded) _guard.release();
        } finally {
          _active = null;
          settled.complete();
        }
      }
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _active?.future;
    try {
      _db.close();
    } finally {
      _guard.close();
    }
  }
}
