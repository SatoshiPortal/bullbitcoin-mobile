import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

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
    final observation = WalletPaymentNotificationIdentity.observation(key(), [
      'private-txid',
    ]);
    expect(
      observation.topicId,
      WalletPaymentNotificationIdentity.topicId(key()),
    );
    expect(observation.eventIds, {
      WalletPaymentNotificationIdentity.eventId(key(), 'private-txid'),
    });
    expect(observation.eventIds.single, matches(RegExp(r'^[a-f0-9]{64}$')));
  });
}
