import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:transaction_sync/transaction_sync.dart';

import 'notifications_test.dart' show FakeGateway;

void main() {
  late Directory directory;
  late SqliteNotificationOutbox outbox;
  late WalletPaymentObservationAdapter adapter;
  final key = WalletKey(id: 'wallet', network: BitcoinNetwork.testnet);

  WalletSyncCompletion completion({
    required bool foreground,
    List<String> incoming = const ['old', 'background', 'foreground'],
    List<String> discovered = const ['foreground'],
  }) => WalletSyncCompletion(
    revision: WalletRevision(key: key, generation: 1, revision: 2),
    incomingTxids: incoming,
    discoveredTxids: discovered,
    completedAt: DateTime.utc(2026),
    completedInForeground: foreground,
  );

  setUp(() {
    directory = Directory.systemTemp.createTempSync('payment-observation-');
    outbox = SqliteNotificationOutbox(databasePath: '${directory.path}/outbox');
    adapter = WalletPaymentObservationAdapter(
      NotificationsFacade(gateway: FakeGateway(), outbox: outbox),
    );
  });
  tearDown(() {
    outbox.dispose();
    directory.deleteSync(recursive: true);
  });

  test(
    'only foreground discoveries become seen, never reread history',
    () async {
      expect(
        await adapter.recordCompletion(completion(foreground: true)),
        isA<Ok>(),
      );
      final db = sqlite3.open('${directory.path}/outbox');
      addTearDown(db.dispose);
      final rows = db.select(
        'SELECT event_id, seen_at FROM notification_outbox',
      );
      final seen = {for (final row in rows) row['event_id']: row['seen_at']};
      expect(seen, hasLength(3));
      expect(
        seen[WalletPaymentNotificationIdentity.eventId(key, 'old')],
        isNull,
      );
      expect(
        seen[WalletPaymentNotificationIdentity.eventId(key, 'background')],
        isNull,
      );
      expect(
        seen[WalletPaymentNotificationIdentity.eventId(key, 'foreground')],
        isNotNull,
      );
      expect((await outbox.claimPending() as Ok).value, isEmpty);
    },
  );

  test(
    'completion visibility controls whether a baseline is recorded',
    () async {
      expect(
        await adapter.recordCompletion(completion(foreground: false)),
        isA<Ok>(),
      );
      final db = sqlite3.open('${directory.path}/outbox');
      addTearDown(db.dispose);
      expect(db.select('SELECT * FROM notification_topics'), isEmpty);
      expect(db.select('SELECT * FROM notification_outbox'), isEmpty);
      expect(
        await adapter.recordCompletion(completion(foreground: true)),
        isA<Ok>(),
      );
      expect(db.select('SELECT * FROM notification_topics'), hasLength(1));
    },
  );

  test('an existing baseline never absorbs a background payment', () async {
    expect(
      await adapter.recordCompletion(
        completion(foreground: true, incoming: ['old'], discovered: []),
      ),
      isA<Ok>(),
    );
    expect(
      await adapter.recordCompletion(completion(foreground: true)),
      isA<Ok>(),
    );
    final db = sqlite3.open('${directory.path}/outbox');
    addTearDown(db.dispose);
    expect(
      db.select('SELECT * FROM notification_outbox WHERE event_id=?', [
        WalletPaymentNotificationIdentity.eventId(key, 'background'),
      ]),
      isEmpty,
    );
  });

  test('discoveries must belong to immutable incoming observations', () {
    expect(
      () => completion(foreground: true, incoming: []),
      throwsArgumentError,
    );
    expect(
      () => completion(foreground: true).incomingTxids.add('mutation'),
      throwsUnsupportedError,
    );
  });
}
