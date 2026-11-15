import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/features/wallet/data/payment_notifications.dart';
import 'package:sqlite3/sqlite3.dart';
import 'dart:async';
import 'dart:io';
import 'package:bb_mobile/features/wallet/data/wallet_payment_observer.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';
import 'package:flutter_test/flutter_test.dart';

class Gateway implements LocalNotificationPort {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'outbox initialization retries after a transient directory failure',
    () async {
      final directory = Directory.systemTemp.createTempSync('payment-open-');
      var attempts = 0;
      final store = PaymentNotificationStore(() async {
        if (attempts++ == 0) throw const FileSystemException('injected');
        return directory.path;
      }, () async => null);
      addTearDown(() async {
        await store.close();
        directory.deleteSync(recursive: true);
      });
      await expectLater(store.open(), throwsA(isA<FileSystemException>()));
      final notifications = await store.open();
      expect(await store.open(), same(notifications));
      expect(attempts, 2);
    },
  );
  test('visibility is captured before asynchronous outbox setup', () async {
    final directory = Directory.systemTemp.createTempSync(
      'payment-observation-',
    );
    final outbox = switch (openForegroundNotificationStore(
      '${directory.path}/outbox.sqlite',
    )) {
      Ok(:final value) => value,
      Err(:final failure) => fail('$failure'),
    };
    addTearDown(() async {
      await outbox.close();
      directory.deleteSync(recursive: true);
    });
    final key = WalletKey(id: 'test', network: BitcoinNetwork.testnet);
    final notifications = NotificationsFacade(
      gateway: Gateway(),
      outbox: outbox,
    );
    SyncCompletion completion(Set<String> incoming) => SyncCompletion(
      SyncMode.revealedScripts,
      Duration.zero,
      revision: WalletRevision(key: key, generation: 1, revision: 2),
      incomingTxids: incoming,
    );
    expect(
      await WalletPaymentObserver.foreground(
        () async => notifications,
        isForeground: () => true,
      ).recordCompletion(completion({})),
      isA<Ok>(),
    );
    final ready = Completer<NotificationsFacade>();
    var visible = true;
    final observer = WalletPaymentObserver.foreground(
      () => ready.future,
      isForeground: () => visible,
    );
    final recording = observer.recordCompletion(completion({'new'}));
    visible = false;
    ready.complete(notifications);
    expect(await recording, isA<Ok>());
    final database = sqlite3.open('${directory.path}/outbox.sqlite');
    try {
      expect(database.select('SELECT 1 FROM observed_events'), hasLength(1));
    } finally {
      database.dispose();
    }
  });

  group('announcements', () {
    late Directory directory;
    late NotificationStoreRepository store;
    late _ShowingGateway gateway;
    late NotificationsFacade notifications;
    final key = WalletKey(id: 'wallet', network: BitcoinNetwork.testnet);
    SyncCompletion seen(Set<String> incoming) => SyncCompletion(
      SyncMode.revealedScripts,
      Duration.zero,
      revision: WalletRevision(key: key, generation: 1, revision: 1),
      incomingTxids: incoming,
    );
    BackgroundSyncOutcome found(Set<String>? incoming) => BackgroundSyncOutcome(
      revision: WalletRevision(key: key, generation: 1, revision: 2),
      incomingTxids: incoming,
      completedAt: DateTime.utc(2026),
    );
    WalletPaymentObserver foreground(bool visible) =>
        WalletPaymentObserver.foreground(
          () async => notifications,
          isForeground: () => visible,
        );
    WalletPaymentObserver background() => WalletPaymentObserver.background(
      () async => notifications,
      copy: (count) => (title: 'Payments', body: '$count'),
    );

    setUp(() {
      directory = Directory.systemTemp.createTempSync('payment-announce-');
      store = switch (openForegroundNotificationStore(
        '${directory.path}/notifications.sqlite',
      )) {
        Ok(:final value) => value,
        Err(:final failure) => fail('$failure'),
      };
      gateway = _ShowingGateway();
      notifications = NotificationsFacade(gateway: gateway, outbox: store);
    });
    tearDown(() async {
      await store.close();
      directory.deleteSync(recursive: true);
    });

    test('identities differ per chain and network and hide raw ids', () async {
      final networks = <Network>[
        ...BitcoinNetwork.values,
        ...LiquidNetwork.values,
      ];
      for (final network in networks) {
        final completion = SyncCompletion(
          SyncMode.revealedScripts,
          Duration.zero,
          revision: WalletRevision(
            key: WalletKey(id: 'private-wallet', network: network),
            generation: 1,
            revision: 1,
          ),
          incomingTxids: {'private-txid'},
        );
        expect(await foreground(true).recordCompletion(completion), isA<Ok>());
      }
      final database = sqlite3.open('${directory.path}/notifications.sqlite');
      addTearDown(database.dispose);
      final topics = database.select('SELECT topic_id FROM topics');
      final events = database.select('SELECT event_id FROM observed_events');
      expect(topics.map((row) => row['topic_id']).toSet(), hasLength(7));
      expect(events.map((row) => row['event_id']).toSet(), hasLength(7));
      for (final row in [...topics, ...events]) {
        expect(row.values.single, matches(RegExp(r'^[a-f0-9]{64}$')));
      }
    });

    test('announces once what only the background found', () async {
      // Hidden: no baseline, so the background stays silent.
      expect(
        await foreground(false).recordCompletion(seen({'old'})),
        isA<Ok>(),
      );
      expect(await background().record(found({'old', 'new'})), isA<Ok>());
      expect(await background().deliverPending(), isA<Ok>());
      expect(gateway.shown, isEmpty);

      expect(await foreground(true).recordCompletion(seen({'old'})), isA<Ok>());
      expect(await background().record(found({'old', 'new'})), isA<Ok>());
      // A replayed complete history announces nothing more.
      expect(await background().record(found({'old', 'new'})), isA<Ok>());
      expect(await background().record(found(null)), isA<Ok>());
      expect(await background().deliverPending(), isA<Ok>());
      expect(gateway.shown.map((n) => n.body), ['1']);
    });

    test('a refused permission is final, a failed store retries', () async {
      expect(await foreground(true).recordCompletion(seen({})), isA<Ok>());
      gateway.enabled = false;
      expect(
        await background().deliverPending(),
        isA<Err<void, PaymentAnnouncementFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<PaymentAnnouncementDeniedFailure>(),
        ),
      );
      final database = sqlite3.open('${directory.path}/notifications.sqlite');
      addTearDown(database.dispose);
      database.execute(
        "CREATE TRIGGER reject BEFORE INSERT ON observed_events BEGIN SELECT RAISE(ABORT, 'injected'); END",
      );
      expect(
        await background().record(found({'new'})),
        isA<Err<void, PaymentAnnouncementFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<PaymentAnnouncementUnavailableFailure>(),
        ),
      );
    });
  });
}

final class _ShowingGateway implements LocalNotificationPort {
  final List<LocalNotification> shown = [];
  bool enabled = true;
  @override
  Future<Result<void, NotificationsFailure>> initialize() async =>
      const Ok(null);
  @override
  Future<Result<bool, NotificationsFailure>> isEnabled() async => Ok(enabled);
  @override
  Future<Result<bool, NotificationsFailure>> requestPermission() async =>
      Ok(enabled);
  @override
  Future<Result<void, NotificationsFailure>> openSystemSettings() async =>
      const Ok(null);
  @override
  Future<Result<void, NotificationsFailure>> show(
    LocalNotification notification, {
    required int platformId,
  }) async {
    shown.add(notification);
    return const Ok(null);
  }
}
