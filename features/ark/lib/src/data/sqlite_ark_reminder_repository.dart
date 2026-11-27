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

typedef _Policy = ({
  bool current,
  String? original,
  Map<String, int> bounds,
  Set<String> copied,
  Set<String> funding,
  bool cancel,
});

/// A separate durable reminder ledger. Negative platform IDs cannot collide
/// with the payment outbox's positive IDs. A permanent sibling guard serializes
/// committed desired actions and their platform effects across all engines.
final class SqliteArkReminderRepository implements ArkReminderRepository {
  final Database _db;
  final ArkReminderGuard _guard;
  final ScheduledNotificationPort _notifications;
  final String title;
  final String body;
  final Future<bool> Function(Fingerprint parent)? _permitsParent;
  bool _closed = false;
  Completer<void>? _active;
  SqliteArkReminderRepository._(
    this._db,
    this._guard,
    this._notifications, {
    required this.title,
    required this.body,
    this._permitsParent,
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
    Future<bool> Function(Fingerprint parent)? permitsParent,
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
      _validateRows(db.select('SELECT * FROM ark_reminders'));
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
          permitsParent: permitsParent,
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
    ArkReminderPolicyEvidence? policyEvidence,
  }) async {
    if (_closed) return const Err(ArkFeatureStorageFailure());
    if (_active != null) return const Err(ArkOperationBusyFailure());
    if ((warning != null &&
            (warning.account != account ||
                warning.revision != revision ||
                warning.tipHeight != tipHeight)) ||
        (policyEvidence != null &&
            (policyEvidence.account != account ||
                policyEvidence.revision != revision ||
                policyEvidence.tipHeight != tipHeight))) {
      return const Err(ArkInvalidRequestFailure());
    }
    final settled = Completer<void>();
    _active = settled;
    var admitted = false;
    var guarded = false;
    try {
      // The owner's permission decides every alarm, new ones included: a
      // refused owner gets none, and the alarm it already has is cancelled.
      final permit = _permitsParent;
      if (permit != null && !await permit(account.parent)) {
        return await _cancelAccountAlarms(account);
      }
      _guard.acquire();
      guarded = true;
      _db.execute('BEGIN IMMEDIATE');
      admitted = true;
      final rows = _db.select('SELECT * FROM ark_reminders');
      _validateRows(rows);
      final legacy = rows
          .where((r) => r['account'] == account.canonical)
          .firstOrNull;
      final currentKey = _vtxoKey(account.canonical);
      final current = rows.where((r) => r['account'] == currentKey).firstOrNull;
      if ([legacy, current].whereType<Row>().any(
        (r) =>
            revision < (r['revision'] as int) || tipHeight < (r['tip'] as int),
      )) {
        _db.execute('COMMIT');
        admitted = false;
        return legacy != null && _policy(legacy)?.cancel == false
            ? const Err(ArkReminderMigrationFailure())
            : const Ok(null);
      }
      final old = legacy == null ? null : _policy(legacy);
      final copied = {...?old?.copied};
      final funding = {...?old?.funding};
      if (old != null && policyEvidence != null) {
        final vtxos = policyEvidence.vtxoKeys.map(_keyHash).toSet();
        final boards = policyEvidence.fundingKeys.map(_keyHash).toSet();
        copied.addAll(
          old.bounds.keys.where(
            (k) =>
                vtxos.contains(k) &&
                !boards.contains(k) &&
                !funding.contains(k),
          ),
        );
        funding.addAll(
          old.bounds.keys.where(
            (k) =>
                boards.contains(k) && !vtxos.contains(k) && !copied.contains(k),
          ),
        );
      }
      final deadlines = current == null
          ? <String, int>{}
          : {...?_policy(current)?.bounds};
      void retain(String key, int at) {
        final previous = deadlines[key];
        if (previous == null || at < previous) deadlines[key] = at;
      }

      if (old != null) {
        for (final key in copied.difference(old.copied)) {
          final at = old.bounds[key];
          if (at == null) throw const FormatException('Missing copied bound');
          retain(key, at);
        }
      }
      if (warning != null) {
        for (final e in warning.deadlines.entries) {
          retain(_keyHash(e.key), e.value.microsecondsSinceEpoch);
        }
        for (final key in warning.retiredKeys) {
          deadlines.remove(_keyHash(key));
        }
      }
      if (authoritativeEmpty) deadlines.clear();
      if (current != null || deadlines.isNotEmpty || copied.isNotEmpty) {
        final id =
            current?['platform_id'] as int? ??
            (_db
                    .select(
                      'SELECT COALESCE(MIN(platform_id),0)-1 AS next FROM ark_reminders',
                    )
                    .single['next']
                as int);
        if (id < -2147483647) {
          throw const FormatException('Reminder ids exhausted');
        }
        final at = deadlines.isEmpty
            ? null
            : deadlines.values.reduce((a, b) => a < b ? a : b);
        final signature = at == null
            ? null
            : sha256.convert(utf8.encode(jsonEncode(deadlines))).toString();
        _db.execute(
          'INSERT INTO ark_reminders VALUES(?,?,?,?,?,?,?) ON CONFLICT(account) DO UPDATE SET revision=excluded.revision,tip=excluded.tip,signature=excluded.signature,scheduled_at=excluded.scheduled_at,deadline_bounds=excluded.deadline_bounds',
          [
            currentKey,
            id,
            revision,
            tipHeight,
            signature,
            at,
            jsonEncode({'format': 2, 'family': 'vtxo', 'bounds': deadlines}),
          ],
        );
      }
      if (old != null) {
        final cancel = copied.length + funding.length == old.bounds.length;
        _db.execute(
          'UPDATE ark_reminders SET revision=?,tip=?,scheduled_at=?,deadline_bounds=? WHERE account=?',
          [
            revision,
            tipHeight,
            cancel ? null : legacy?['scheduled_at'],
            jsonEncode({
              'format': 2,
              'family': 'legacy',
              'original': old.original,
              'vtxo': copied.toList(),
              'funding': funding.toList(),
              'intent': cancel ? 'cancel' : 'hold',
            }),
            account.canonical,
          ],
        );
      }
      final desired = _db.select('SELECT * FROM ark_reminders');
      _validateRows(desired);
      _db.execute('COMMIT');
      admitted = false;
      return await _replay(
        desired.where((r) => _owner(r) == account.canonical).toList(),
      );
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
    final policy = _policy(row);
    if (policy == null) {
      if (signature != null ||
          at != null ||
          bounds != null ||
          account.startsWith('[')) {
        throw const FormatException('Invalid reminder cancellation');
      }
    } else {
      _owner(row);
      if (policy.cancel) {
        if (at != null ||
            (!policy.current &&
                (signature is! String ||
                    !RegExp(r'^[0-9a-f]{64}$').hasMatch(signature))) ||
            (policy.current &&
                (signature != null || policy.bounds.isNotEmpty))) {
          throw const FormatException('Invalid policy cancellation');
        }
      } else if (signature is! String ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(signature) ||
          at is! int ||
          policy.bounds.isEmpty ||
          at != policy.bounds.values.reduce((a, b) => a < b ? a : b)) {
        throw const FormatException('Invalid policy schedule');
      }
    }
  }

  static String _vtxoKey(String owner) =>
      jsonEncode(['ark-vtxo-intent:2', owner]);
  static String _owner(Row row) {
    final key = row['account'] as String;
    if (_policy(row)?.current != true) {
      if (key.startsWith('[')) {
        throw const FormatException('Legacy purpose mismatch');
      }
      return key;
    }
    final Object? decoded = jsonDecode(key);
    if (decoded case ['ark-vtxo-intent:2', final String owner]
        when owner.isNotEmpty && _vtxoKey(owner) == key) {
      return owner;
    }
    throw const FormatException('VTXO purpose mismatch');
  }

  static Set<String> _classifications(
    Object? encoded,
    Map<String, int> bounds,
  ) {
    if (encoded is! List) {
      throw const FormatException('Invalid policy classification');
    }
    final result = encoded.whereType<String>().toSet();
    if (result.length != encoded.length || !result.every(bounds.containsKey)) {
      throw const FormatException('Invalid policy classification');
    }
    return result;
  }

  static _Policy? _policy(Row row) {
    final encoded = row['deadline_bounds'];
    if (encoded == null) return null;
    if (encoded is! String) {
      throw const FormatException('Invalid reminder encoding');
    }
    final Object? value = jsonDecode(encoded);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid reminder encoding');
    }
    if (!value.containsKey('format')) {
      return (
        current: false,
        original: encoded,
        bounds:
            _readBounds(encoded) ??
            (throw const FormatException('Invalid legacy bounds')),
        copied: <String>{},
        funding: <String>{},
        cancel: false,
      );
    }
    if (value['format'] is! int || value['format'] != 2) {
      throw const FormatException('Unsupported reminder policy');
    }
    if (value['family'] == 'vtxo' && value.length == 3) {
      final raw = value['bounds'];
      final bounds = raw is Map && raw.isEmpty && row['signature'] == null
          ? <String, int>{}
          : _readBounds(jsonEncode(raw));
      if (bounds == null) throw const FormatException('Invalid VTXO bounds');
      return (
        current: true,
        original: null,
        bounds: bounds,
        copied: <String>{},
        funding: <String>{},
        cancel: row['signature'] == null,
      );
    }
    final original = value['original'];
    if (value['family'] != 'legacy' ||
        value.length != 6 ||
        original is! String) {
      throw const FormatException('Invalid legacy envelope');
    }
    final bounds = _readBounds(original);
    if (bounds == null) throw const FormatException('Invalid original bounds');
    final copied = _classifications(value['vtxo'], bounds);
    final funding = _classifications(value['funding'], bounds);
    final cancel = copied.length + funding.length == bounds.length;
    if (copied.intersection(funding).isNotEmpty ||
        value['intent'] != (cancel ? 'cancel' : 'hold')) {
      throw const FormatException('Invalid legacy policy state');
    }
    return (
      current: false,
      original: original,
      bounds: bounds,
      copied: copied,
      funding: funding,
      cancel: cancel,
    );
  }

  static void _validateRows(List<Row> rows) {
    for (final row in rows) {
      _validateDesired(row);
    }
    for (final row in rows) {
      final policy = _policy(row);
      if (policy != null &&
          !policy.current &&
          policy.copied.isNotEmpty &&
          !rows.any(
            (r) =>
                r['account'] == _vtxoKey(_owner(row)) &&
                _policy(r)?.current == true,
          )) {
        throw const FormatException('Missing VTXO replacement');
      }
    }
  }

  Future<Result<void, ArkFailure>> _replay(List<Row> rows) async {
    ArkFailure? failed;
    var unresolved = false;
    final replacements = <String, bool>{};
    for (final row in rows.where((r) => _policy(r)?.current == true)) {
      final at = row['scheduled_at'] as int?;
      final result = await _apply(
        row['platform_id'] as int,
        at == null
            ? null
            : DateTime.fromMicrosecondsSinceEpoch(at, isUtc: true),
      );
      replacements[_owner(row)] = result is Ok;
      if (result case Err(:final failure)) failed ??= failure;
    }
    for (final row in rows.where((r) => _policy(r)?.current != true)) {
      final policy = _policy(row);
      if (policy?.cancel == false) {
        unresolved = true;
        continue;
      }
      if (policy != null &&
          policy.copied.isNotEmpty &&
          replacements[_owner(row)] != true) {
        continue;
      }
      final result = await _apply(row['platform_id'] as int, null);
      if (result case Err(:final failure)) failed ??= failure;
    }
    return failed != null
        ? Err(failed)
        : unresolved
        ? const Err(ArkReminderMigrationFailure())
        : const Ok(null);
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
  Future<Result<void, ArkFailure>> reapplyStored({
    Future<bool> Function(Fingerprint parent)? permitsParent,
  }) async {
    permitsParent ??= _permitsParent;
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
      _validateRows(desired);
      _db.execute('COMMIT');
      admitted = false;
      final filter = permitsParent;
      if (filter == null) return await _replay(desired);
      final split = await _splitByPermission(desired, filter);
      final replayed = await _replay(split.permitted);
      // An alarm already programmed for a view that no longer permits it must
      // not fire: cancel it. The ledger row stays, so the foreground can
      // schedule it again once the view permits it.
      ArkFailure? cancelFailed;
      for (final row in split.refused) {
        final cancelled = await _apply(row['platform_id'] as int, null);
        if (cancelled case Err(:final failure)) cancelFailed ??= failure;
      }
      if (replayed case Err()) return replayed;
      return cancelFailed != null ? Err(cancelFailed) : replayed;
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

  /// Cancels the OS alarms of [account] and keeps its ledger rows, so the
  /// foreground can schedule them again once its owner permits it.
  Future<Result<void, ArkFailure>> _cancelAccountAlarms(
    ArkAccountId account,
  ) async {
    try {
      ArkFailure? failed;
      for (final row in _db.select('SELECT * FROM ark_reminders')) {
        final String owner;
        try {
          owner = _owner(row);
        } on Object {
          continue;
        }
        if (owner != account.canonical) continue;
        final cancelled = await _apply(row['platform_id'] as int, null);
        if (cancelled case Err(:final failure)) failed ??= failure;
      }
      return failed == null ? const Ok(null) : Err(failed);
    } on Exception {
      return const Err(ArkFeatureStorageFailure());
    }
  }

  /// Splits the rows by whether the caller still permits their exact owner,
  /// asking once per parent. A row whose owner cannot be read is refused:
  /// reapplying an alarm is never what proves the view may still see it.
  Future<({List<Row> permitted, List<Row> refused})> _splitByPermission(
    List<Row> rows,
    Future<bool> Function(Fingerprint parent) permitsParent,
  ) async {
    final decisions = <String, bool>{};
    final permitted = <Row>[];
    final refused = <Row>[];
    for (final row in rows) {
      Fingerprint? parent;
      try {
        parent = Fingerprint(_owner(row).split('|').first);
      } on Object {
        parent = null;
      }
      final allowed =
          parent != null &&
          (decisions[parent.hex] ??= await permitsParent(parent));
      (allowed ? permitted : refused).add(row);
    }
    return (permitted: permitted, refused: refused);
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
