import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:bull_ark/src/data/sqlite_ark_reminder_repository.dart';
import 'package:bull_ark/ark_foreground_maintenance_setup.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

import 'ark_durable_stores_test.dart' show value;
import 'ark_maintenance_schedule_test.dart' show Registry;
import 'fake_ark_client.dart';
import 'ark_operations_test.dart' show account;
import 'ark_reminder_deadline_test.dart' show warning;

class Gateway implements ScheduledNotificationPort {
  final actions = <({int id, DateTime? at})>[];
  Completer<void>? hold;
  bool fail = false;
  bool throwBeforeEffect = false;
  bool throwAfterEffect = false;
  SendPort? entered;

  @override
  Future<Result<void, NotificationsFailure>> schedule(
    LocalNotification notification, {
    required int platformId,
    required DateTime at,
    bool cancelExisting = true,
  }) async {
    if (throwBeforeEffect) throw Exception('Before OS effect');
    actions.add((id: platformId, at: at));
    entered?.send('effect');
    await hold?.future;
    if (throwAfterEffect) throw Exception('Lost OS completion');
    return fail ? const Err(NotificationsGatewayFailure()) : const Ok(null);
  }

  @override
  Future<Result<void, NotificationsFailure>> cancelScheduled(
    int platformId,
  ) async {
    if (throwBeforeEffect) throw Exception('Before OS effect');
    actions.add((id: platformId, at: null));
    await hold?.future;
    if (throwAfterEffect) throw Exception('Lost OS completion');
    return fail ? const Err(NotificationsGatewayFailure()) : const Ok(null);
  }
}

Future<void> initialize((String, SendPort) args) async {
  final commands = ReceivePort();
  args.$2.send(commands.sendPort);
  await commands.first;
  final result = SqliteArkReminderRepository.open(
    path: args.$1,
    notifications: Gateway(),
    title: 'Urgent',
    body: 'Open Ark',
    foreground: true,
    initializeNew: true,
  );
  if (result case Ok(:final value)) await value.close();
  args.$2.send(result is Ok);
  commands.close();
}

Future<void> holdAlarm((String, SendPort) args) async {
  final port = Gateway()
    ..hold = Completer<void>()
    ..entered = args.$2;
  final store = value(
    SqliteArkReminderRepository.open(
      path: args.$1,
      notifications: port,
      title: 'Urgent',
      body: 'Open Ark',
      foreground: false,
    ),
  );
  await store.reconcile(
    account: account(),
    warning: warning(
      revision: 6,
      tip: 499,
      at: DateTime.utc(2026, 11, 16),
      live: {'old': 500},
    ),
    authoritativeEmpty: false,
    revision: 6,
    tipHeight: 499,
  );
  await store.close();
}

void main() {
  late Directory directory;
  late String path;
  late Gateway gateway;
  late SqliteArkReminderRepository store;
  final initial = DateTime.utc(2026, 11, 16);
  final later = warning(tip: 100, at: initial, live: {'old': 500});
  final earlier = warning(
    revision: 6,
    tip: 499,
    at: initial,
    live: {'old': 500},
  );

  SqliteArkReminderRepository open(Gateway port, {bool initialize = false}) =>
      value(
        SqliteArkReminderRepository.open(
          path: path,
          notifications: port,
          title: 'Urgent',
          body: 'Open Ark',
          foreground: initialize,
          initializeNew: initialize,
        ),
      );

  Future<Result<void, ArkFailure>> apply({
    bool accelerate = false,
    bool cancel = false,
  }) => store.reconcile(
    account: account(),
    warning: cancel ? null : (accelerate ? earlier : later),
    authoritativeEmpty: cancel,
    revision: accelerate || cancel ? 6 : 5,
    tipHeight: accelerate || cancel ? 499 : 100,
  );

  Map<String, Object?> row() {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      return Map.of(db.select('SELECT * FROM ark_reminders').single);
    } finally {
      db.close();
    }
  }

  setUp(() {
    directory = Directory.systemTemp.createTempSync('ark-alarm-lifecycle-');
    path = '${directory.path}/ledger';
    gateway = Gateway();
    store = open(gateway, initialize: true);
  });
  tearDown(() async {
    final held = gateway.hold;
    if (held != null && !held.isCompleted) held.complete();
    await store.close();
    directory.deleteSync(recursive: true);
  });

  test('unavailable notification plugin keeps stored reminders and opens maintenance', () async {
    expect(await apply(), isA<Ok>());
    final saved = row();
    await store.close();
    final result = await openArkForegroundMaintenance(
      path: path,
      locale: const Locale('en'),
      client: FakeArkClient(),
      accounts: Registry(),
      initializeNew: false,
    );
    expect(result, isA<Ok<ArkForegroundMaintenance, ArkFailure>>());
    final maintenance =
        (result as Ok<ArkForegroundMaintenance, ArkFailure>).value;
    expect(maintenance.remindersReady, false);
    await maintenance.close();
    expect(row(), saved);
  });

  test(
    'earlier intent is committed while the OS call is still pending',
    () async {
      await apply();
      final held = Completer<void>();
      gateway.hold = held;
      final pending = apply(accelerate: true);
      await Future<void>.delayed(Duration.zero);
      final committed = row()['scheduled_at'];
      held.complete();
      gateway.hold = null;
      await pending;
      expect(committed, earlier.notifyAt.microsecondsSinceEpoch);
    },
  );

  test(
    'failed scheduling preserves earlier desired intent for offline replay',
    () async {
      await apply();
      gateway.fail = true;
      expect(await apply(accelerate: true), isA<Err<void, ArkFailure>>());
      await store.close();
      final restarted = Gateway();
      store = open(restarted);
      expect(await store.reapplyStored(), isA<Ok>());
      expect(restarted.actions.single.at, earlier.notifyAt);
      expect(restarted.actions.single.id, gateway.actions.first.id);
    },
  );

  test(
    'failed cancellation remains committed and is replayed offline',
    () async {
      await apply();
      gateway.fail = true;
      expect(await apply(cancel: true), isA<Err<void, ArkFailure>>());
      await store.close();
      final restarted = Gateway();
      store = open(restarted);
      expect(await store.reapplyStored(), isA<Ok>());
      expect(restarted.actions, [(id: gateway.actions.first.id, at: null)]);
      expect(row()['signature'], null);
      expect(row()['scheduled_at'], null);
    },
  );

  test(
    'completed cancellation keeps its stable id and replays cancel',
    () async {
      await apply();
      await apply(cancel: true);
      await store.close();
      final restarted = Gateway();
      store = open(restarted);
      expect(await store.reapplyStored(), isA<Ok>());
      expect(restarted.actions, [(id: gateway.actions.first.id, at: null)]);
    },
  );

  test(
    'guard excludes another engine after desired commit until OS settlement',
    () async {
      await apply();
      final secondGateway = Gateway();
      final second = open(secondGateway);
      final held = Completer<void>();
      gateway.hold = held;
      final pending = apply(accelerate: true);
      await Future<void>.delayed(Duration.zero);
      try {
        final raw = sqlite3.open(path);
        raw.execute(
          'BEGIN IMMEDIATE',
        ); // The ledger writer is already released.
        raw.execute('ROLLBACK');
        raw.close();
        expect(await second.reapplyStored(), isA<Err>());
        expect(
          await second.reconcile(
            account: account(),
            warning: null,
            authoritativeEmpty: true,
            revision: 7,
            tipHeight: 500,
          ),
          isA<Err>(),
        );
        expect(secondGateway.actions, isEmpty);
        expect(row()['scheduled_at'], earlier.notifyAt.microsecondsSinceEpoch);
      } finally {
        held.complete();
        gateway.hold = null;
        await pending;
        await second.close();
      }
    },
  );

  test(
    'close refuses new admission and drains an unfinished cancellation',
    () async {
      await apply();
      final held = Completer<void>();
      gateway.hold = held;
      final pending = apply(cancel: true);
      await Future<void>.delayed(Duration.zero);
      var closed = false;
      final closing = store.close().then((_) => closed = true);
      await Future<void>.delayed(Duration.zero);
      expect(closed, false);
      expect(await store.reapplyStored(), isA<Err>());
      expect(await apply(accelerate: true), isA<Err>());
      held.complete();
      gateway.hold = null;
      expect(await pending, isA<Ok>());
      await closing;
      expect(closed, true);
      final restarted = open(Gateway());
      await restarted.close();
    },
  );

  test(
    'commit failure permits no OS action and retains prior intent',
    () async {
      await apply();
      final raw = sqlite3.open(path);
      raw.execute(
        "CREATE TRIGGER fail_desired BEFORE UPDATE ON ark_reminders BEGIN SELECT RAISE(ABORT,'test commit refusal'); END",
      );
      raw.close();
      expect(await apply(accelerate: true), isA<Err>());
      expect(gateway.actions, [(id: -1, at: later.notifyAt)]);
      expect(row()['scheduled_at'], later.notifyAt.microsecondsSinceEpoch);
    },
  );

  for (final before in [true, false]) {
    test(
      'interruption beforeEffect=$before replays committed earlier intent',
      () async {
        await apply();
        gateway.throwBeforeEffect = before;
        gateway.throwAfterEffect = !before;
        expect(
          await apply(accelerate: true),
          isA<Err<void, ArkFailure>>().having(
            (result) => result.failure,
            'uncertain OS result',
            isA<ArkReminderUnavailableFailure>(),
          ),
        );
        expect(row()['scheduled_at'], earlier.notifyAt.microsecondsSinceEpoch);
        await store.close();
        final restarted = Gateway();
        store = open(restarted);
        expect(await store.reapplyStored(), isA<Ok>());
        expect(restarted.actions.single, (id: -1, at: earlier.notifyAt));
      },
    );
  }

  for (final damaged in [
    'missing guard',
    'truncated guard',
    'corrupt guard',
    'symlink guard',
    'WAL guard',
    'missing ledger',
    'corrupt ledger',
    'missing marker',
    'torn marker',
  ]) {
    test('$damaged refuses startup without recreating metadata', () async {
      await apply();
      await store.close();
      final guard = File('$path.guard');
      final ledger = File(path);
      final marker = File('$path.initialized');
      switch (damaged) {
        case 'missing guard':
          guard.deleteSync();
        case 'truncated guard':
          guard.writeAsBytesSync([]);
        case 'corrupt guard':
          guard.writeAsStringSync('invalid sqlite');
        case 'symlink guard':
          final other = guard.copySync('$path.other');
          guard.deleteSync();
          Link(guard.path).createSync(other.path);
        case 'WAL guard':
          final raw = sqlite3.open(guard.path);
          raw.execute('PRAGMA journal_mode=WAL');
          raw.close();
        case 'missing ledger':
          ledger.deleteSync();
        case 'corrupt ledger':
          ledger.writeAsStringSync('invalid sqlite');
        case 'missing marker':
          marker.deleteSync();
        case 'torn marker':
          marker.writeAsStringSync('ark-reminders:');
      }
      final before = [
        guard.existsSync(),
        ledger.existsSync(),
        marker.existsSync(),
      ];
      for (final foreground in [false, true]) {
        final result = SqliteArkReminderRepository.open(
          path: path,
          notifications: Gateway(),
          title: 'Urgent',
          body: 'Open Ark',
          foreground: foreground,
          initializeNew: foreground && damaged != 'missing marker',
        );
        if (result case Ok(:final value)) await value.close();
        expect(result, isA<Err>());
        expect([
          guard.existsSync(),
          ledger.existsSync(),
          marker.existsSync(),
        ], before);
      }
    });
  }

  for (final retainGuard in [false, true]) {
    test(
      'legacy adoption preserves state after guardCreated=$retainGuard',
      () async {
        await apply();
        final original = row();
        await store.close();
        File('$path.initialized').writeAsStringSync('ark-reminders:1\n');
        if (!retainGuard) File('$path.guard').deleteSync();
        for (final foreground in [false, true]) {
          final refused = SqliteArkReminderRepository.open(
            path: path,
            notifications: Gateway(),
            title: 'Urgent',
            body: 'Open Ark',
            foreground: foreground,
            initializeNew: true,
            migrateLegacy: !foreground,
          );
          expect(refused, isA<Err>());
          expect(File('$path.guard').existsSync(), retainGuard);
        }
        final restarted = Gateway();
        store = value(
          SqliteArkReminderRepository.open(
            path: path,
            notifications: restarted,
            title: 'Urgent',
            body: 'Open Ark',
            foreground: true,
            migrateLegacy: true,
          ),
        );
        expect(row(), original);
        expect(
          File('$path.initialized').readAsStringSync(),
          'ark-reminders:2\n',
        );
        expect(await store.reapplyStored(), isA<Ok>());
        expect(restarted.actions.single, (id: -1, at: later.notifyAt));
      },
    );
  }

  for (final checkpoint in ['guard only', 'ledger committed']) {
    test(
      'explicit first setup resumes from $checkpoint without reset',
      () async {
        final interrupted = '${directory.path}/interrupted';
        final guard = sqlite3.open('$interrupted.guard');
        guard.userVersion = 1;
        guard.close();
        if (checkpoint == 'ledger committed') {
          final created = value(
            SqliteArkReminderRepository.open(
              path: interrupted,
              notifications: Gateway(),
              title: 'Urgent',
              body: 'Open Ark',
              foreground: true,
              initializeNew: true,
            ),
          );
          await created.reconcile(
            account: account(),
            warning: earlier,
            authoritativeEmpty: false,
            revision: 6,
            tipHeight: 499,
          );
          await created.close();
          File('$interrupted.initialized').deleteSync();
        }
        final port = Gateway();
        final resumed = value(
          SqliteArkReminderRepository.open(
            path: interrupted,
            notifications: port,
            title: 'Urgent',
            body: 'Open Ark',
            foreground: true,
            initializeNew: true,
          ),
        );
        expect(await resumed.reapplyStored(), isA<Ok>());
        expect(
          port.actions,
          checkpoint == 'ledger committed'
              ? [(id: -1, at: earlier.notifyAt)]
              : isEmpty,
        );
        await resumed.close();
      },
    );
  }

  test('concurrent first initializers share one permanent guard', () async {
    final concurrent = '${directory.path}/concurrent';
    final ports = [ReceivePort(), ReceivePort()];
    final events = ports.map(StreamIterator<dynamic>.new).toList();
    final isolates = <Isolate>[];
    try {
      for (var i = 0; i < 2; i++) {
        isolates.add(
          await Isolate.spawn(initialize, (concurrent, ports[i].sendPort)),
        );
      }
      final starters = <SendPort>[];
      for (final stream in events) {
        expect(
          await stream.moveNext().timeout(const Duration(seconds: 5)),
          true,
        );
        starters.add(stream.current as SendPort);
      }
      for (final start in starters) {
        start.send('start');
      }
      final results = <bool>[];
      for (final stream in events) {
        expect(
          await stream.moveNext().timeout(const Duration(seconds: 5)),
          true,
        );
        results.add(stream.current as bool);
      }
      expect(results, contains(true));
      expect(
        File('$concurrent.initialized').readAsStringSync(),
        'ark-reminders:2\n',
      );
      final completed = value(
        SqliteArkReminderRepository.open(
          path: concurrent,
          notifications: Gateway(),
          title: 'Urgent',
          body: 'Open Ark',
          foreground: false,
        ),
      );
      await completed.close();
    } finally {
      for (final isolate in isolates) {
        isolate.kill(priority: Isolate.immediate);
      }
      for (final stream in events) {
        await stream.cancel();
      }
      for (final port in ports) {
        port.close();
      }
    }
  });

  test(
    'killed holder keeps guard exclusion after earlier intent committed',
    () async {
      await apply();
      final messages = ReceivePort();
      final exited = ReceivePort();
      final isolate = await Isolate.spawn(holdAlarm, (
        path,
        messages.sendPort,
      ), onExit: exited.sendPort);
      try {
        expect(
          await messages.first.timeout(const Duration(seconds: 5)),
          'effect',
        );
        isolate.kill(priority: Isolate.immediate);
        await exited.first.timeout(const Duration(seconds: 5));
        expect(row()['scheduled_at'], earlier.notifyAt.microsecondsSinceEpoch);
        final count = gateway.actions.length;
        expect(await store.reapplyStored(), isA<Err>());
        expect(await apply(cancel: true), isA<Err>());
        expect(gateway.actions.length, count);
      } finally {
        isolate.kill(priority: Isolate.immediate);
        messages.close();
        exited.close();
      }
    },
  );
}
