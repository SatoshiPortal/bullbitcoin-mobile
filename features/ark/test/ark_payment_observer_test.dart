import 'dart:io';

import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart';
import 'package:bull_ark/src/data/ark_payment_observer.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

final account = ArkAccountId(
  parent: Fingerprint('00112233'),
  network: BitcoinNetwork.regtest,
  serverIdentity: 'https://ark.example',
);

final class Gateway implements LocalNotificationPort {
  final shown = <LocalNotification>[];
  bool fail = false;
  bool enabled = true;

  @override
  Future<Result<void, NotificationsFailure>> initialize() async =>
      const Ok(null);
  @override
  Future<Result<bool, NotificationsFailure>> isEnabled() async => Ok(enabled);
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
  }) async {
    if (fail) return const Err(NotificationsGatewayFailure());
    shown.add(notification);
    return const Ok(null);
  }
}

final class Exits implements ArkExitObserverPort {
  int observed = 0;
  int claims = 0;
  @override
  Future<void> observe(ArkPassOutcome outcome) async => observed++;
  @override
  Future<void> claimAdmitted(ArkAccountId account, ArkOperation claim) async =>
      claims++;
}

ArkMovement movement(
  String id, {
  ArkMovementKind kind = ArkMovementKind.payment,
  ArkMovementStatus status = ArkMovementStatus.successful,
  ArkMovementDirection direction = ArkMovementDirection.incoming,
}) => ArkMovement(
  id: id,
  kind: kind,
  status: status,
  direction: direction,
  amount: Sats.fromInt(1000),
);

ArkPassOutcome pass(
  List<ArkMovement> movements, {
  bool stale = false,
  ArkRecoveryStatus recovery = ArkRecoveryStatus.complete,
  Set<ArkStage> completed = const {ArkStage.ark},
  List<String> failed = const [],
}) => ArkPassOutcome(
  snapshot: ArkSnapshot(
    account: account,
    revision: 1,
    observedAt: DateTime.utc(2026, 11, 25),
    stale: stale,
    recovery: recovery,
    movements: movements,
  ),
  completedStages: completed,
  failedStages: failed,
);

void main() {
  late Directory directory;
  late NotificationStoreRepository store;
  late NotificationsFacade facade;
  late Gateway gateway;
  late Exits exits;

  ArkPaymentObserver observer({required bool foreground}) => ArkPaymentObserver(
    notifications: facade,
    exits: exits,
    foreground: foreground,
    copy: (count) => (title: 'Received', body: '$count'),
  );

  setUp(() {
    directory = Directory.systemTemp.createTempSync('ark-payment-');
    gateway = Gateway();
    exits = Exits();
    store =
        (openForegroundNotificationStore('${directory.path}/outbox.sqlite')
                as Ok<NotificationStoreRepository, NotificationsFailure>)
            .value;
    facade = NotificationsFacade(outbox: store, gateway: gateway);
  });

  tearDown(() async {
    await store.close();
    directory.deleteSync(recursive: true);
  });

  test(
    'foreground baseline, native kinds, restart and deduplication',
    () async {
      final foreground = observer(foreground: true);
      await foreground.observe(pass([movement('old')]));
      expect(exits.observed, 0, reason: 'foreground never observes exits');

      final background = observer(foreground: false);
      await background.observe(pass([movement('old')]));
      expect(gateway.shown, isEmpty);

      await background.observe(
        pass([
          movement('old'),
          movement('ark'),
          movement('ln', kind: ArkMovementKind.lightningReceive),
          movement('board', kind: ArkMovementKind.board),
          movement('round', kind: ArkMovementKind.renewal),
          movement('exit', kind: ArkMovementKind.exit),
          movement('sent', direction: ArkMovementDirection.outgoing),
          movement('unknown', direction: ArkMovementDirection.unknown),
          movement('pending', status: ArkMovementStatus.pending),
          movement('failed', status: ArkMovementStatus.failed),
        ]),
      );
      expect(gateway.shown, hasLength(1));
      expect(gateway.shown.single.body, '2');
      expect(exits.observed, 2);

      // A reopened store and a repeated history announce nothing again.
      await store.close();
      store =
          (openForegroundNotificationStore('${directory.path}/outbox.sqlite')
                  as Ok<NotificationStoreRepository, NotificationsFailure>)
              .value;
      facade = NotificationsFacade(outbox: store, gateway: gateway);
      await observer(foreground: false).observe(
        pass([movement('old'), movement('ark'), movement('ln')]),
      );
      expect(gateway.shown, hasLength(1));
    },
  );

  test('uninitialized, stale and failed syncs never announce', () async {
    final background = observer(foreground: false);
    await background.observe(pass([movement('first')]));
    expect(gateway.shown, isEmpty, reason: 'no baseline yet');
    await observer(foreground: true).observe(pass([]));
    for (final outcome in [
      pass([movement('a')], stale: true),
      pass([movement('b')], recovery: ArkRecoveryStatus.incomplete),
      pass([movement('c')], completed: const {}),
      pass([movement('d')], failed: const ['ark']),
    ]) {
      await background.observe(outcome);
    }
    expect(gateway.shown, isEmpty);
    await background.observe(pass([movement('e')]));
    expect(gateway.shown, hasLength(1));
  });

  test('a restored history first seen in foreground is a baseline', () async {
    await observer(foreground: true).observe(
      pass([movement('r1'), movement('r2')]),
    );
    await observer(foreground: false).observe(
      pass([movement('r1'), movement('r2')]),
    );
    expect(gateway.shown, isEmpty);
  });

  test('a failed delivery is retried after reopening the outbox', () async {
    await observer(foreground: true).observe(pass([]));
    gateway.fail = true;
    await expectLater(
      observer(foreground: false).observe(pass([movement('x')])),
      throwsA(isA<FormatException>()),
    );
    expect(gateway.shown, isEmpty);
    gateway.fail = false;
    await observer(foreground: false).observe(pass([movement('x')]));
    expect(gateway.shown, hasLength(1));
    await observer(foreground: false).observe(pass([movement('x')]));
    expect(gateway.shown, hasLength(1));
  });

  test('claim admission is forwarded to the exit notifier', () async {
    await observer(foreground: true).claimAdmitted(
      account,
      ArkOperation(
        id: 'claim',
        kind: ArkOperationKind.claim,
        status: ArkOperationStatus.succeeded,
        chainSource: Uri.parse('https://chain.example'),
        configGeneration: 1,
      ),
    );
    expect(exits.claims, 1);
  });
}
