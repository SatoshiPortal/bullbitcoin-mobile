import 'dart:async';
import 'dart:io';

import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart';
import 'package:bull_ark/ark_maintenance_setup.dart';
import 'package:bull_ark/src/data/ark_exit_notifier.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/domain/repositories/ark_account_registry_repository.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'claimable_exit_groups_test.dart' show account, exit, operation, pass;
import 'ark_expiry_warning_test.dart' show Reminders;
import 'fake_ark_client.dart';

final class Registry implements ArkAccountRegistryRepository {
  @override
  Future<Result<List<ArkAccountConfig>, ArkFailure>> list() async => Ok([
    ArkAccountConfig(
      id: account,
      arkUrl: Uri.parse('https://ark.example'),
      primaryEsploraUrl: Uri.parse('https://chain.example'),
    ),
  ]);

  @override
  Future<Result<void, ArkFailure>> publish(ArkAccountConfig config) async =>
      const Ok(null);
}

final class ObservingClient extends FakeArkClient {
  final ArkExitNotifier observer;
  ObservingClient(this.observer);

  @override
  Future<Result<ArkPassOutcome, ArkWalletFailure>> synchronize(
    ArkAccountId account, {
    required bool renew,
  }) async {
    final result = await super.synchronize(account, renew: renew);
    if (result case Ok(:final value)) await observer.observe(value);
    return result;
  }
}

final class Gateway implements LocalNotificationPort {
  @override
  Future<Result<void, NotificationsFailure>> initialize() async =>
      const Ok(null);
  @override
  Future<Result<bool, NotificationsFailure>> isEnabled() async =>
      const Ok(true);
  @override
  Future<Result<void, NotificationsFailure>> openSystemSettings() async =>
      const Ok(null);
  @override
  Future<Result<bool, NotificationsFailure>> requestPermission() async =>
      const Ok(true);
  @override
  Future<Result<void, NotificationsFailure>> show(
    LocalNotification notification, {
    required int platformId,
  }) async => const Ok(null);
}

final class Scheduled implements ScheduledNotificationPort {
  final shown = <int>[];
  final cancelled = <int>[];
  final cancelBeforeShow = <bool>[];
  bool failCancel = false;
  Completer<Result<void, NotificationsFailure>>? heldCancel;
  NotificationsFailure? showFailure;
  @override
  Future<Result<void, NotificationsFailure>> schedule(
    LocalNotification notification, {
    required int platformId,
    required DateTime at,
    bool cancelExisting = true,
  }) async {
    final failure = showFailure;
    if (failure != null) return Err(failure);
    cancelBeforeShow.add(cancelExisting);
    shown.add(platformId);
    return const Ok(null);
  }

  @override
  Future<Result<void, NotificationsFailure>> cancelScheduled(
    int platformId,
  ) async {
    final held = heldCancel;
    if (held != null) return held.future;
    if (failCancel) return const Err(NotificationsGatewayFailure());
    cancelled.add(platformId);
    return const Ok(null);
  }
}

void main() {
  late Directory directory;
  late NotificationStoreRepository store;
  late NotificationsFacade allocator;
  late Scheduled scheduled;
  late ArkExitNotifier notifier;

  ArkExitNotifier open({required bool foreground}) => ArkExitNotifier.open(
    path: '${directory.path}/exits.sqlite',
    foreground: foreground,
    allocator: allocator,
    notifications: scheduled,
    budget: const ArkUnlimitedStageBudget(),
    title: 'Ready',
    body: 'Open the app',
  );

  setUp(() {
    directory = Directory.systemTemp.createTempSync('ark-exit-notice-');
    store = (openForegroundNotificationStore(
      '${directory.path}/outbox.sqlite',
    ) as Ok<NotificationStoreRepository, NotificationsFailure>).value;
    allocator = NotificationsFacade(outbox: store, gateway: Gateway());
    scheduled = Scheduled();
    notifier = open(foreground: true);
  });

  tearDown(() async {
    notifier.close();
    await store.close();
    directory.deleteSync(recursive: true);
  });

  test('only a complete group is shown, once across restart', () async {
    final first = exit('a', ArkExitStatus.claimable);
    await notifier.observe(
      pass(exits: [first, exit('b', ArkExitStatus.pending)]),
    );
    expect(scheduled.shown, isEmpty);
    final ready = pass(exits: [first, exit('b', ArkExitStatus.claimable)]);
    await notifier.observe(ready);
    notifier.close();
    notifier = open(foreground: false);
    await notifier.observe(ready);
    expect(scheduled.shown, hasLength(1));
    expect(scheduled.cancelBeforeShow, [false]);
  });

  test('an initialized store cannot be silently recreated after loss', () {
    final path = '${directory.path}/other.sqlite';
    final other = ArkExitNotifier.open(
      path: path,
      foreground: true,
      allocator: allocator,
      notifications: scheduled,
      budget: const ArkUnlimitedStageBudget(),
      title: 'Ready',
      body: 'Open the app',
    );
    other.close();
    File(path).deleteSync();
    expect(
      () => ArkExitNotifier.open(
        path: path,
        foreground: true,
        allocator: allocator,
        notifications: scheduled,
        budget: const ArkUnlimitedStageBudget(),
        title: 'Ready',
        body: 'Open the app',
      ),
      throwsFormatException,
    );
    expect(File(path).existsSync(), isFalse);
  });

  test('foreground can finish publishing an empty initialized store', () {
    final path = '${directory.path}/interrupted.sqlite';
    final other = ArkExitNotifier.open(
      path: path,
      foreground: true,
      allocator: allocator,
      notifications: scheduled,
      budget: const ArkUnlimitedStageBudget(),
      title: 'Ready',
      body: 'Open the app',
    );
    other.close();
    File('$path.initialized').deleteSync();
    final recovered = ArkExitNotifier.open(
      path: path,
      foreground: true,
      allocator: allocator,
      notifications: scheduled,
      budget: const ArkUnlimitedStageBudget(),
      title: 'Ready',
      body: 'Open the app',
    );
    recovered.close();
    expect(File('$path.initialized').existsSync(), isTrue);
  });

  test('invalid durable state is refused without a platform effect', () async {
    final ready = pass(
      exits: [
        exit('a', ArkExitStatus.claimable),
        exit('b', ArkExitStatus.claimable),
      ],
    );
    await notifier.observe(ready);
    notifier.close();
    final db = sqlite3.open('${directory.path}/exits.sqlite');
    db.execute("UPDATE exit_notices SET members='not-json'");
    db.close();
    expect(() => open(foreground: false), throwsFormatException);
    expect(scheduled.shown, hasLength(1));
    final repair = sqlite3.open('${directory.path}/exits.sqlite');
    repair.execute('UPDATE exit_notices SET members=?', ['["a","b"]']);
    repair.close();
    notifier = open(foreground: false);
  });

  test('corruption after open fails as a recoverable exception', () async {
    await notifier.observe(
      pass(
        exits: [
          exit('a', ArkExitStatus.claimable),
          exit('b', ArkExitStatus.claimable),
        ],
      ),
    );
    final db = sqlite3.open('${directory.path}/exits.sqlite');
    db.execute('UPDATE exit_notices SET members=?', ['[1]']);
    db.close();
    await expectLater(
      notifier.claimAdmitted(
        account,
        operation('claim', ArkOperationKind.claim, ['a']),
      ),
      throwsFormatException,
    );
  });

  test('claim cancellation is retried after failure and restart', () async {
    final ready = pass(
      exits: [
        exit('a', ArkExitStatus.claimable),
        exit('b', ArkExitStatus.claimable),
      ],
    );
    await notifier.observe(ready);
    scheduled.failCancel = true;
    final claim = operation('claim', ArkOperationKind.claim, ['a']);
    await expectLater(
      notifier.claimAdmitted(account, claim),
      throwsFormatException,
    );
    notifier.close();
    notifier = open(foreground: false);
    scheduled.failCancel = false;
    await notifier.claimAdmitted(account, claim);
    await notifier.observe(ready);
    expect(scheduled.cancelled, scheduled.shown);
    expect(scheduled.shown, hasLength(1));
  });

  test('a later observation cancels an already journalled claim', () async {
    final exits = [
      exit('a', ArkExitStatus.claimable),
      exit('b', ArkExitStatus.claimable),
    ];
    await notifier.observe(pass(exits: exits));
    notifier.close();
    notifier = open(foreground: false);
    await notifier.observe(
      pass(
        exits: exits,
        operations: [
          operation('group', ArkOperationKind.emergencyExit, ['a', 'b']),
          operation('claim', ArkOperationKind.claim, ['a']),
        ],
      ),
    );
    expect(scheduled.cancelled, scheduled.shown);
    expect(scheduled.shown, hasLength(1));
  });

  test(
    'a fresh loss of readiness withdraws the alert, but stale data does not',
    () async {
      final ready = [
        exit('a', ArkExitStatus.claimable),
        exit('b', ArkExitStatus.claimable),
      ];
      final immature = [ready.first, exit('b', ArkExitStatus.pending)];
      await notifier.observe(pass(exits: ready));
      await notifier.observe(pass(exits: immature, stale: true));
      expect(scheduled.cancelled, isEmpty);
      await notifier.observe(pass(exits: immature));
      expect(scheduled.cancelled, scheduled.shown);
      await notifier.observe(pass(exits: ready));
      expect(scheduled.shown, hasLength(1));
    },
  );

  test('a stuck platform cancellation leaves a durable retry', () async {
    final ready = pass(
      exits: [
        exit('a', ArkExitStatus.claimable),
        exit('b', ArkExitStatus.claimable),
      ],
    );
    await notifier.observe(ready);
    final held = Completer<Result<void, NotificationsFailure>>();
    scheduled.heldCancel = held;
    final claim = operation('claim', ArkOperationKind.claim, ['a']);
    await expectLater(
      notifier.claimAdmitted(account, claim),
      throwsA(isA<TimeoutException>()),
    );
    notifier.close();
    notifier = open(foreground: false);
    scheduled.heldCancel = null;
    await notifier.claimAdmitted(account, claim);
    held.complete(const Ok(null));
    expect(scheduled.cancelled, scheduled.shown);
  });

  test('an unavailable notification is retried only on a fresh pass', () async {
    final exits = [
      exit('a', ArkExitStatus.claimable),
      exit('b', ArkExitStatus.claimable),
    ];
    scheduled.showFailure = const NotificationsGatewayFailure();
    await expectLater(
      notifier.observe(pass(exits: exits)),
      throwsFormatException,
    );
    notifier.close();
    notifier = open(foreground: false);
    scheduled.showFailure = null;
    await notifier.observe(pass(exits: exits, stale: true));
    expect(scheduled.shown, isEmpty);
    await notifier.observe(pass(exits: exits));
    expect(scheduled.shown, hasLength(1));
  });

  test('refused permission does not replay after permission changes', () async {
    final ready = pass(
      exits: [
        exit('a', ArkExitStatus.claimable),
        exit('b', ArkExitStatus.claimable),
      ],
    );
    scheduled.showFailure = const NotificationsPermissionDeniedFailure();
    await notifier.observe(ready);
    scheduled.showFailure = null;
    await notifier.observe(ready);
    expect(scheduled.shown, isEmpty);
  });

  test('worker checks saved claims before observing the exit', () async {
    final exits = [
      exit('a', ArkExitStatus.claimable),
      exit('b', ArkExitStatus.claimable),
    ];
    final snapshot = ArkSnapshot(
      account: account,
      revision: 1,
      observedAt: DateTime.utc(2026),
      tipHeight: 100,
      stale: false,
      vtxoCompleteness: ArkSectionCompleteness.complete,
      recovery: ArkRecoveryStatus.complete,
      exitDetails: exits,
      operations: [
        operation('group', ArkOperationKind.emergencyExit, ['a', 'b']),
      ],
    );
    final client = ObservingClient(notifier)
      ..snapshot = Ok(snapshot)
      ..pass = Ok(
        ArkPassOutcome(
          snapshot: snapshot,
          completedStages: {ArkStage.exits, ArkStage.vtxos},
        ),
      );
    final handler = ArkMaintenance(
      client: client,
      reminders: Reminders(),
      accounts: Registry(),
      budget: const ArkUnlimitedStageBudget(),
    ).backgroundHandler();
    await handler();
    await handler();
    expect(client.calls, ['read', 'renew', 'read', 'renew']);
    expect(scheduled.shown, hasLength(1));
  });
}
