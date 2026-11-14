import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:transaction_sync/transaction_sync.dart';

import 'notifications_test.dart' show FakeGateway;

void main() {
  test(
    'stored history derives discoveries and preserves background provenance',
    () async {
      final directory = Directory.systemTemp.createTempSync('observation-');
      final path = '${directory.path}/outbox';
      final outbox = SqliteNotificationOutbox(databasePath: path);
      final facade = NotificationsFacade(
        gateway: FakeGateway(),
        outbox: outbox,
      );
      final adapter = WalletPaymentObservationAdapter(facade);
      final key = WalletKey(id: 'wallet', network: BitcoinNetwork.testnet);
      final topic = WalletPaymentNotificationIdentity.topicId(key);
      LocalNotification event(String id) =>
          WalletPaymentNotificationIdentity.event(
            key,
            id,
            observedAt: DateTime.utc(2026),
          );
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
      addTearDown(() {
        database.close();
        outbox.dispose();
        directory.deleteSync(recursive: true);
      });
      await observe(['old'], foreground: false);
      expect(database.select('SELECT * FROM notification_topics'), isEmpty);
      await observe(['old']);
      expect(
        database
            .select('SELECT seen_at FROM notification_outbox')
            .single['seen_at'],
        isNull,
      );
      expect(
        await facade.reconcileTopicsAndEnqueue([
          NotificationTopicObservation(topic, [
            event('old'),
            event('background'),
          ]),
        ], (_) => event('aggregate')),
        isA<Ok>(),
      );
      await observe(['old', 'background', 'foreground']);
      await observe(['old', 'background', 'foreground']);
      Object? seen(String id) => database.select(
        'SELECT seen_at FROM notification_outbox WHERE event_id=?',
        [event(id).eventId],
      ).single['seen_at'];
      expect(seen('old'), isNull);
      expect(seen('background'), isNull);
      expect(seen('foreground'), isNotNull);
      expect((await outbox.claimPending() as Ok).value, hasLength(1));
    },
  );
}
