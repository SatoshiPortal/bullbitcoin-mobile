import 'package:address_view/payment_destination.dart';
import 'package:bull_exchange/src/btc_network_destination.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases = <(BtcNetwork, PaymentDestinationType)>[
    (BtcNetwork.bitcoin, PaymentDestinationType.bitcoin),
    (BtcNetwork.liquid, PaymentDestinationType.liquid),
    (BtcNetwork.lightning, PaymentDestinationType.lightningAddress),
  ];
  for (final (network, type) in cases) {
    test('a $network payout accepts $type', () {
      expect(network.destinationType, type);
    });
  }
}
