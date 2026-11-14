import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

void main() {
  test('payment identity distinguishes chain and typed network', () {
    final topics = <String>{};
    final events = <String>{};
    for (final network in <Network>[
      ...BitcoinNetwork.values,
      ...LiquidNetwork.values,
    ]) {
      final key = WalletKey(id: 'wallet', network: network);
      topics.add(WalletPaymentNotificationIdentity.topicId(key));
      events.add(WalletPaymentNotificationIdentity.eventId(key, 'txid'));
    }
    expect(topics, hasLength(7));
    expect(events, hasLength(7));
    expect(topics.intersection(events), isEmpty);
  });

  test('reconstructing a key preserves identity without raw ids', () {
    WalletKey key() =>
        WalletKey(id: 'private-wallet', network: BitcoinNetwork.testnet);
    final event = WalletPaymentNotificationIdentity.event(
      key(),
      'private-txid',
      observedAt: DateTime.utc(2026),
    );
    expect(
      event.eventId,
      WalletPaymentNotificationIdentity.eventId(key(), 'private-txid'),
    );
    expect(event.eventId, matches(RegExp(r'^[a-f0-9]{64}$')));
    expect(event.destination, NotificationDestination.walletHome);
  });
}
