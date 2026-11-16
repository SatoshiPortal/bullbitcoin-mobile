import 'dart:async';
import 'dart:io';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/data/sqlite_ark_account_registry.dart';
import 'package:bull_ark/src/data/sqlite_ark_reminder_repository.dart';
import 'package:bull_ark/src/domain/ark_expiry_warning.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import 'ark_operations_test.dart' show account;
import 'ark_expiry_warning_test.dart' show observed, vtxo;

class Notifications implements ScheduledNotificationPort {
  final scheduled = <({int id, DateTime at})>[];
  final cancelled = <int>[];
  Completer<void>? hold;
  @override
  Future<Result<void, NotificationsFailure>> schedule(
    LocalNotification notification, {
    required int platformId,
    required DateTime at,
  }) async {
    scheduled.add((id: platformId, at: at));
    await hold?.future;
    return const Ok(null);
  }

  @override
  Future<Result<void, NotificationsFailure>> cancelScheduled(
    int platformId,
  ) async {
    cancelled.add(platformId);
    return const Ok(null);
  }
}

T value<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err() => throw StateError('Expected successful fixture construction'),
};
void main() {
  late Directory directory;
  setUp(() => directory = Directory.systemTemp.createTempSync('ark-stores-'));
  tearDown(() => directory.deleteSync(recursive: true));
  ArkAccountConfig config() => ArkAccountConfig(
    id: account(),
    arkUrl: Uri.parse('https://ark.second.tech'),
    primaryEsploraUrl: Uri.parse('https://example.com'),
  );
  test('existing-only registry does not create missing custody metadata', () {
    final path = '${directory.path}/missing';
    expect(SqliteArkAccountRegistry.open(path, foreground: false), isA<Err>());
    expect(File(path).existsSync(), false);
  });
  test(
    'durable reference survives reopen and malformed inventory fails closed',
    () async {
      final path = '${directory.path}/accounts';
      final first = value(
        SqliteArkAccountRegistry.open(
          path,
          foreground: true,
          initializeNew: true,
        ),
      );
      expect(await first.publish(config()), isA<Ok>());
      first.close();
      final reopened = value(
        SqliteArkAccountRegistry.open(path, foreground: false),
      );
      expect(value(await reopened.getCustodyFingerprints()), {
        account().parent,
      });
      reopened.close();
      final raw = sqlite3.open(path);
      raw.execute("UPDATE ark_accounts SET config='{}'");
      raw.close();
      final corrupted = value(
        SqliteArkAccountRegistry.open(path, foreground: false),
      );
      expect(await corrupted.getCustodyFingerprints(), isA<Err>());
      corrupted.close();
    },
  );
  test('same account configuration is idempotent and changed provider cannot overwrite', () async {
    final store = value(
      SqliteArkAccountRegistry.open(
        '${directory.path}/accounts',
        foreground: true,
        initializeNew: true,
      ),
    );
    expect(await store.publish(config()), isA<Ok>());
    expect(await store.publish(config()), isA<Ok>());
    final changed = ArkAccountConfig(
      id: account(),
      arkUrl: Uri.parse('https://ark.second.tech'),
      primaryEsploraUrl: Uri.parse('https://other.example'),
    );
    expect(await store.publish(changed), isA<Err>());
    expect(value(await store.list()).length, 1);
    store.close();
  });
  SqliteArkReminderRepository reminders(
    String path,
    Notifications notifications, {
    bool foreground = true,
  }) => value(
    SqliteArkReminderRepository.open(
      path: path,
      notifications: notifications,
      title: 'Urgent',
      body: 'Open Ark',
      foreground: foreground,
      initializeNew: foreground,
    ),
  );
  ArkExpiryWarning warning(int tip, {int revision = 5}) =>
      switch (ArkExpiryWarning.fromSnapshot(
        observed(tip: tip, revision: revision, vtxos: [vtxo('old', 500)]),
      )) {
        final warning? => warning,
        null => throw StateError('Missing fixture warning'),
      };
  test('startup reapply retains stable ID and deadline for same inputs after restart', () async {
    final path = '${directory.path}/reminders';
    final gateway = Notifications();
    final first = reminders(path, gateway);
    expect(
      await first.reconcile(
        account: account(),
        warning: warning(100),
        authoritativeEmpty: false,
        revision: 5,
        tipHeight: 100,
      ),
      isA<Ok>(),
    );
    await first.close();
    final reopened = reminders(path, gateway, foreground: false);
    expect(
      await reopened.reconcile(
        account: account(),
        warning: warning(110, revision: 6),
        authoritativeEmpty: false,
        revision: 6,
        tipHeight: 110,
      ),
      isA<Ok>(),
    );
    expect(gateway.scheduled.length, 2);
    expect(gateway.scheduled.first.id, gateway.scheduled.last.id);
    expect(gateway.scheduled.last.at, warning(110).notifyAt);
    expect(
      gateway.scheduled.last.at.isBefore(gateway.scheduled.first.at),
      true,
    );
    expect(gateway.scheduled.first.id, isNegative);
    await reopened.close();
  });
  test('regressing provider tip cannot cancel observed expiry', () async {
    final gateway = Notifications();
    final store = reminders('${directory.path}/reminders', gateway);
    await store.reconcile(
      account: account(),
      warning: warning(100),
      authoritativeEmpty: false,
      revision: 5,
      tipHeight: 100,
    );
    await store.reconcile(
      account: account(),
      warning: null,
      authoritativeEmpty: true,
      revision: 6,
      tipHeight: 99,
    );
    expect(gateway.cancelled, isEmpty);
    await store.reconcile(
      account: account(),
      warning: null,
      authoritativeEmpty: true,
      revision: 7,
      tipHeight: 101,
    );
    expect(gateway.cancelled, [gateway.scheduled.single.id]);
    await store.close();
  });
  test('second connection cannot mutate while admitted schedule waits; close drains it', () async {
    final path = '${directory.path}/reminders';
    final gateway = Notifications()..hold = Completer<void>();
    final first = reminders(path, gateway);
    final second = reminders(path, Notifications(), foreground: false);
    final pending = first.reconcile(
      account: account(),
      warning: warning(100),
      authoritativeEmpty: false,
      revision: 5,
      tipHeight: 100,
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      await second.reconcile(
        account: account(),
        warning: null,
        authoritativeEmpty: true,
        revision: 6,
        tipHeight: 101,
      ),
      isA<Err<void, ArkFailure>>(),
    );
    var closed = false;
    final closing = first.close().then((_) {
      closed = true;
    });
    await Future<void>.delayed(Duration.zero);
    expect(closed, false);
    gateway.hold?.complete();
    expect(await pending, isA<Ok>());
    await closing;
    expect(closed, true);
    await second.close();
  });
  test(
    'offline startup reapply uses stored warning without a new native snapshot',
    () async {
      final path = '${directory.path}/reminders';
      final gateway = Notifications();
      final first = reminders(path, gateway);
      await first.reconcile(
        account: account(),
        warning: warning(100),
        authoritativeEmpty: false,
        revision: 5,
        tipHeight: 100,
      );
      await first.close();
      final reopened = reminders(path, gateway, foreground: false);
      expect(await reopened.reapplyStored(), isA<Ok>());
      expect(gateway.scheduled.length, 2);
      expect(gateway.scheduled.first, gateway.scheduled.last);
      await reopened.close();
    },
  );
  test(
    'missing initialized account metadata cannot be silently recreated',
    () async {
      final path = '${directory.path}/accounts';
      final first = value(
        SqliteArkAccountRegistry.open(
          path,
          foreground: true,
          initializeNew: true,
        ),
      );
      await first.publish(config());
      first.close();
      File(path).deleteSync();
      final reopened = SqliteArkAccountRegistry.open(path, foreground: true);
      if (reopened case Ok(:final value)) value.close();
      expect(reopened, isA<Err>());
    },
  );
  test(
    'missing initialized reminder metadata cannot be silently recreated',
    () async {
      final path = '${directory.path}/reminders';
      final gateway = Notifications();
      final first = reminders(path, gateway);
      await first.reconcile(
        account: account(),
        warning: warning(100),
        authoritativeEmpty: false,
        revision: 5,
        tipHeight: 100,
      );
      await first.close();
      File(path).deleteSync();
      final reopened = SqliteArkReminderRepository.open(
        path: path,
        notifications: gateway,
        title: 'Urgent',
        body: 'Open Ark',
        foreground: true,
      );
      if (reopened case Ok(:final value)) await value.close();
      expect(reopened, isA<Err>());
    },
  );
  test('initialized marker never permits version-zero account reset even with initializeNew', () async {
    final path = '${directory.path}/accounts';
    final first = value(
      SqliteArkAccountRegistry.open(
        path,
        foreground: true,
        initializeNew: true,
      ),
    );
    await first.publish(config());
    first.close();
    File(path).writeAsBytesSync([], flush: true);
    final reset = SqliteArkAccountRegistry.open(
      path,
      foreground: true,
      initializeNew: true,
    );
    if (reset case Ok(:final value)) value.close();
    expect(reset, isA<Err>());
  });
  test('initialized marker never permits version-zero reminder reset even with initializeNew', () async {
    final path = '${directory.path}/reminders';
    final gateway = Notifications();
    final first = reminders(path, gateway);
    await first.reconcile(
      account: account(),
      warning: warning(100),
      authoritativeEmpty: false,
      revision: 5,
      tipHeight: 100,
    );
    await first.close();
    File(path).writeAsBytesSync([], flush: true);
    final reset = SqliteArkReminderRepository.open(
      path: path,
      notifications: gateway,
      title: 'Urgent',
      body: 'Open Ark',
      foreground: true,
      initializeNew: true,
    );
    if (reset case Ok(:final value)) await value.close();
    expect(reset, isA<Err>());
  });
}
