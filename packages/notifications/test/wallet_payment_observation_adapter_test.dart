import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'notifications_test.dart' show FakeGateway, aggregate;

void main() {
  test(
    'only foreground completions initialize and extend the stored history',
    () async {
      final directory = Directory.systemTemp.createTempSync('observation-');
      final path = '${directory.path}/outbox';
      final outbox =
          (SqliteNotificationStoreRepository.openForeground(path)
                  as Ok<
                    SqliteNotificationStoreRepository,
                    NotificationsFailure
                  >)
              .value;
      final facade = NotificationsFacade(
        gateway: FakeGateway(),
        outbox: outbox,
      );
      final adapter = WalletPaymentObservationAdapter(facade);
      final key = WalletKey(id: 'wallet', network: BitcoinNetwork.testnet);
      Future<void> observe(
        List<String> incoming, {
        bool foreground = true,
      }) async {
        expect(
          await adapter.recordCompletion(
            WalletSyncCompletion(
              revision: WalletRevision(key: key, generation: 1, revision: 2),
              incomingTxids: incoming,
              completedAt: DateTime.utc(2026),
              completedInForeground: foreground,
            ),
          ),
          isA<Ok>(),
        );
      }

      final database = sqlite3.open(path);
      addTearDown(() async {
        database.dispose();
        await outbox.close();
        directory.deleteSync(recursive: true);
      });
      await observe(['old'], foreground: false);
      expect(database.select('SELECT * FROM topics'), isEmpty);
      expect(database.select('SELECT * FROM observed_events'), isEmpty);

      await observe(['old']);
      expect(database.select('SELECT * FROM topics'), hasLength(1));
      expect(
        (await facade.recordBackground(
                  WalletPaymentNotificationIdentity.observation(key, [
                    'old',
                    'background',
                  ]),
                  aggregate,
                )
                as Ok)
            .value,
        BackgroundObservation.enqueued,
      );
      await observe(['old', 'background', 'foreground']);
      await observe(['old', 'background', 'foreground']);

      final stored = database
          .select('SELECT event_id FROM observed_events')
          .map((row) => row['event_id'])
          .toSet();
      expect(stored, {
        for (final txid in ['old', 'background', 'foreground'])
          WalletPaymentNotificationIdentity.eventId(key, txid),
      });
      // Rule P is not decided: a pending aggregate waits for its delivery.
      expect((await outbox.claimNext() as Ok).value, isNotNull);
    },
  );
}
