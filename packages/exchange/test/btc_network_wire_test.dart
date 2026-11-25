import 'package:exchange/exchange.dart';
import 'package:exchange/src/data/btc_network_wire.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('order network', () {
    final cases = <(BtcNetwork, String)>[
      (BtcNetwork.bitcoin, 'bitcoin'),
      (BtcNetwork.liquid, 'liquid'),
      (BtcNetwork.lightning, 'lightning'),
    ];
    for (final (network, wire) in cases) {
      test('$network -> $wire', () {
        expect(BtcNetworkWire.orderNetwork(network), wire);
      });
    }
  });

  group('recipient type', () {
    final cases = <(BtcNetwork, String)>[
      (BtcNetwork.bitcoin, 'OUT_BITCOIN_ADDRESS'),
      (BtcNetwork.liquid, 'OUT_LIQUID_ADDRESS'),
      (BtcNetwork.lightning, 'OUT_LIGHTNING_ADDRESS'),
    ];
    for (final (network, wire) in cases) {
      test('$network <-> $wire', () {
        expect(BtcNetworkWire.recipientType(network), wire);
        expect(
          BtcNetworkWire.parseRecipientType(wire),
          KnownBtcNetwork(network),
        );
        expect(BtcNetworkWire.dcaRecipientType(network).value, wire);
      });
    }

    test('an unknown value is Unknown with the raw value, not bitcoin', () {
      expect(
        BtcNetworkWire.parseRecipientType('OUT_ARK_ADDRESS'),
        const UnknownBtcNetwork('OUT_ARK_ADDRESS'),
      );
      expect(
        BtcNetworkWire.parseRecipientType(''),
        const UnknownBtcNetwork(''),
      );
    });

    test('recipientTypes lists the three', () {
      expect(BtcNetworkWire.recipientTypes, [
        'OUT_BITCOIN_ADDRESS',
        'OUT_LIGHTNING_ADDRESS',
        'OUT_LIQUID_ADDRESS',
      ]);
    });
  });
}
