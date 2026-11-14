import 'package:bb_mobile/features/wallet/data/payment_notifications.dart';
import 'package:sqlite3/sqlite3.dart';
import 'dart:async';
import 'dart:io';
import 'package:bb_mobile/features/wallet/data/wallet_payment_observer.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';
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
    final outbox = SqliteNotificationOutbox(
      databasePath: '${directory.path}/outbox.sqlite',
    );
    addTearDown(() {
      outbox.dispose();
      directory.deleteSync(recursive: true);
    });
    final key = WalletKey(id: 'test', network: BitcoinNetwork.testnet);
    final notifications = NotificationsFacade(
      gateway: Gateway(),
      outbox: outbox,
    );
    expect(
      await notifications.recordForeground(
        WalletPaymentNotificationIdentity.observation(key, []),
      ),
      isA<Ok>(),
    );
    final ready = Completer<NotificationsFacade>();
    var visible = true;
    final observer = WalletPaymentObserver(() => ready.future, () => visible);
    final recording = observer.record(
      SyncCompletion(
        SyncMode.revealedScripts,
        Duration.zero,
        revision: WalletRevision(key: key, generation: 1, revision: 2),
        incomingTxids: {'new'},
      ),
    );
    visible = false;
    ready.complete(notifications);
    expect(await recording, isA<Ok>());
    final database = sqlite3.open('${directory.path}/outbox.sqlite');
    try {
      expect(
        database.select('SELECT 1 FROM observed_events WHERE event_id=?', [
          WalletPaymentNotificationIdentity.eventId(key, 'new'),
        ]),
        hasLength(1),
      );
    } finally {
      database.dispose();
    }
  });
}
