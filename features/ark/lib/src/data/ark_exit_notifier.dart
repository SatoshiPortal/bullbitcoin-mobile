import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import '../domain/claimable_exit_groups.dart';

/// Persists notification identities, but never replays a show without a fresh
/// observation. Ark's account writer serializes both callbacks.
final class ArkExitNotifier implements ArkExitObserverPort {
  final Database _db;
  final NotificationsFacade _allocator;
  final ScheduledNotificationPort _notifications;
  final ArkStageBudget _budget;
  final String _title;
  final String _body;

  ArkExitNotifier._(
    this._db,
    this._allocator,
    this._notifications,
    this._budget,
    this._title,
    this._body,
  );

  static ArkExitNotifier open({
    required String path,
    required bool foreground,
    required NotificationsFacade allocator,
    required ScheduledNotificationPort notifications,
    required ArkStageBudget budget,
    required String title,
    required String body,
  }) {
    final requested = File(path);
    final name = requested.uri.pathSegments.last;
    final canonical = '${requested.parent.resolveSymbolicLinksSync()}/$name';
    final file = File(canonical);
    final marker = File('$canonical.initialized');
    for (final name in [file.path, marker.path]) {
      if (FileSystemEntity.typeSync(name, followLinks: false) ==
          FileSystemEntityType.link) {
        throw const FormatException('Invalid exit notification store path');
      }
    }
    final exists = file.existsSync();
    final initialized = marker.existsSync();
    if ((initialized &&
            (!exists || marker.readAsStringSync() != 'ark-exit-notices:1\n')) ||
        (!initialized && !foreground)) {
      throw const FormatException('Exit notification store is unavailable');
    }
    final db = sqlite3.open(
      canonical,
      mode: foreground ? OpenMode.readWriteCreate : OpenMode.readWrite,
    );
    try {
      db.execute('PRAGMA busy_timeout = 0');
      if (db.userVersion == 0 && foreground && !exists) {
        db.execute('BEGIN IMMEDIATE');
        try {
          db.execute(
            'CREATE TABLE exit_notices (account TEXT NOT NULL, group_id TEXT NOT NULL, platform_id INTEGER NOT NULL UNIQUE, members TEXT NOT NULL, state TEXT NOT NULL, PRIMARY KEY(account, group_id))',
          );
          db.userVersion = 1;
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      }
      if (db.userVersion != 1) {
        throw const FormatException('Invalid exit notice store');
      }
      db.select(
        'SELECT account, group_id, platform_id, members, state FROM exit_notices LIMIT 0',
      );
      if (db.select('PRAGMA quick_check').single.values.single != 'ok') {
        throw const FormatException('Invalid exit notification store');
      }
      final rows = db.select('SELECT * FROM exit_notices');
      if (!initialized && rows.isNotEmpty) {
        throw const FormatException('Exit notification marker is missing');
      }
      for (final row in rows) {
        final account = row['account'];
        final group = row['group_id'];
        final id = row['platform_id'];
        final members = row['members'];
        final state = row['state'];
        if (account is! String ||
            account.isEmpty ||
            group is! String ||
            group.isEmpty ||
            id is! int ||
            id <= 0 ||
            id > 2147483647 ||
            members is! String ||
            !{
              'pending',
              'shown',
              'cancel_pending',
              'cancelled',
            }.contains(state)) {
          throw const FormatException('Invalid exit notification record');
        }
        final decoded = jsonDecode(members);
        if (decoded is! List ||
            decoded.isEmpty ||
            decoded.any((value) => value is! String || value.isEmpty)) {
          throw const FormatException('Invalid exit notification members');
        }
      }
      if (!initialized) {
        marker.writeAsStringSync('ark-exit-notices:1\n', flush: true);
      }
      return ArkExitNotifier._(
        db,
        allocator,
        notifications,
        budget,
        title,
        body,
      );
    } catch (_) {
      db.close();
      rethrow;
    }
  }

  @override
  Future<void> observe(ArkPassOutcome outcome) async {
    try {
      await _observe(outcome);
    } on Exception {
      log.warning('Ark exit notification failed');
      rethrow;
    }
  }

  Future<void> _observe(ArkPassOutcome outcome) async {
    final account = outcome.snapshot.account;
    await _cancelClaims(account, outcome.snapshot.operations);
    if (!hasFreshExitObservation(account, outcome)) return;
    final eligible = claimableExitGroups(account, outcome);
    final withdrawn = _db
        .select(
          "SELECT * FROM exit_notices WHERE account=? AND state='shown'",
          [account.canonical],
        )
        .where((row) => !eligible.contains(row['group_id']))
        .toList();
    if (withdrawn.isNotEmpty && _budget.mayAdmitNextStage) {
      await _cancelRows(account, withdrawn);
    }
    for (final group in eligible) {
      if (!_budget.mayAdmitNextStage) return;
      final operation = outcome.snapshot.operations.singleWhere(
        (item) => item.id == group,
      );
      var rows = _db.select(
        'SELECT * FROM exit_notices WHERE account=? AND group_id=?',
        [account.canonical, group],
      );
      if (rows.isEmpty) {
        final reserved = await _allocator.reservePlatformId();
        final id = switch (reserved) {
          Ok(:final value) => value,
          Err() => throw const FormatException('Notification ID unavailable'),
        };
        _db.execute('INSERT INTO exit_notices VALUES (?, ?, ?, ?, ?)', [
          account.canonical,
          group,
          id,
          jsonEncode(operation.actualIds),
          'pending',
        ]);
        rows = _db.select(
          'SELECT * FROM exit_notices WHERE account=? AND group_id=?',
          [account.canonical, group],
        );
      }
      final row = rows.single;
      if (row['state'] != 'pending') continue;
      if (!_budget.mayAdmitNextStage) return;
      final platformId = row['platform_id'];
      if (platformId is! int) {
        throw const FormatException('Invalid exit notification identity');
      }
      final result = await _notifications.schedule(
        LocalNotification(
          eventId: group,
          title: _title,
          body: _body,
          createdAt: DateTime.now().toUtc(),
        ),
        platformId: platformId,
        at: DateTime.now().subtract(const Duration(seconds: 1)),
        cancelExisting: false,
      );
      final settled = switch (result) {
        Ok() || Err(failure: NotificationsPermissionDeniedFailure()) => true,
        Err() => false,
      };
      if (settled) {
        _db.execute(
          "UPDATE exit_notices SET state='shown' WHERE account=? AND group_id=?",
          [account.canonical, group],
        );
      } else {
        throw const FormatException('Exit notification unavailable');
      }
    }
  }

  @override
  Future<void> claimAdmitted(ArkAccountId account, ArkOperation claim) async {
    try {
      await _cancelClaims(account, [claim]);
    } on Exception {
      log.warning('Ark exit notification cancellation failed');
      rethrow;
    }
  }

  Future<void> _cancelClaims(
    ArkAccountId account,
    List<ArkOperation> operations,
  ) async {
    final claimed = {
      for (final op in operations)
        if (op.kind == ArkOperationKind.claim) ...op.actualIds,
    };
    final unknownClaim = operations.any(
      (op) => op.kind == ArkOperationKind.claim && op.actualIds.isEmpty,
    );
    final rows = <Row>[];
    for (final row in _db.select('SELECT * FROM exit_notices WHERE account=?', [
      account.canonical,
    ])) {
      final rawMembers = row['members'];
      final group = row['group_id'];
      final platformId = row['platform_id'];
      if (rawMembers is! String || group is! String || platformId is! int) {
        throw const FormatException('Invalid exit notification record');
      }
      final decoded = jsonDecode(rawMembers);
      if (decoded is! List || decoded.any((value) => value is! String)) {
        throw const FormatException('Invalid exit notification members');
      }
      final members = decoded.cast<String>();
      if (row['state'] == 'cancelled') continue;
      if (row['state'] != 'cancel_pending' &&
          !unknownClaim &&
          !members.any(claimed.contains)) {
        continue;
      }
      rows.add(row);
    }
    await _cancelRows(account, rows);
  }

  Future<void> _cancelRows(ArkAccountId account, Iterable<Row> rows) async {
    final clock = Stopwatch()..start();
    for (final row in rows) {
      final group = row['group_id'];
      final platformId = row['platform_id'];
      if (group is! String || platformId is! int) {
        throw const FormatException('Invalid exit notification record');
      }
      _db.execute(
        "UPDATE exit_notices SET state='cancel_pending' WHERE account=? AND group_id=?",
        [account.canonical, group],
      );
      final remaining = const Duration(seconds: 2) - clock.elapsed;
      if (remaining <= Duration.zero) {
        throw TimeoutException('Exit cancellation timed out');
      }
      final cancelled = await _notifications
          .cancelScheduled(platformId)
          .timeout(remaining);
      if (cancelled is Err) {
        throw const FormatException('Exit cancellation unavailable');
      }
      _db.execute(
        "UPDATE exit_notices SET state='cancelled' WHERE account=? AND group_id=?",
        [account.canonical, group],
      );
    }
  }

  void close() => _db.close();
}
