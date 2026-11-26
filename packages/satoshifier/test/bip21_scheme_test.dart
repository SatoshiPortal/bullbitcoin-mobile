import 'package:flutter_test/flutter_test.dart';
import 'package:satoshifier/satoshifier.dart';
import 'package:satoshifier/_test_value.dart';

void main() {
  group('Bip21Parser scheme consistency', () {
    test('bitcoin: accepts any bitcoin network', () {
      for (final network in Network.values.where((n) => n.isBitcoin)) {
        expect(
          Bip21Parser.schemeMatchesNetwork('bitcoin', network),
          isTrue,
          reason: '$network',
        );
      }
    });

    test('bitcoin: refuses a liquid address', () {
      expect(
        Bip21Parser.schemeMatchesNetwork('bitcoin', Network.liquidMainnet),
        isFalse,
      );
      expect(
        Bip21Parser.schemeMatchesNetwork('bitcoin', Network.liquidTestnet),
        isFalse,
      );
    });

    test('the liquid schemes are held to the network they name', () {
      expect(
        Bip21Parser.schemeMatchesNetwork(
          'liquidnetwork',
          Network.liquidMainnet,
        ),
        isTrue,
      );
      expect(
        Bip21Parser.schemeMatchesNetwork('liquid', Network.liquidMainnet),
        isTrue,
      );
      expect(
        Bip21Parser.schemeMatchesNetwork(
          'liquidtestnet',
          Network.liquidTestnet,
        ),
        isTrue,
      );

      // The case the finding describes: a mainnet Liquid address inside a
      // 'liquidtestnet:' URI used to parse and report liquidMainnet.
      expect(
        Bip21Parser.schemeMatchesNetwork(
          'liquidtestnet',
          Network.liquidMainnet,
        ),
        isFalse,
      );
      expect(
        Bip21Parser.schemeMatchesNetwork(
          'liquidnetwork',
          Network.liquidTestnet,
        ),
        isFalse,
      );
    });

    test('is case-insensitive, as uppercased QR URIs require', () {
      expect(
        Bip21Parser.schemeMatchesNetwork('BITCOIN', Network.bitcoinMainnet),
        isTrue,
      );
      expect(
        Bip21Parser.schemeMatchesNetwork(
          'LIQUIDTESTNET',
          Network.liquidTestnet,
        ),
        isTrue,
      );
    });

    test('an unknown scheme matches nothing', () {
      expect(
        Bip21Parser.schemeMatchesNetwork('ethereum', Network.bitcoinMainnet),
        isFalse,
      );
    });

    test('a consistent bitcoin URI still parses', () async {
      final parsed = await Bip21Parser.parse(
        'bitcoin:${TestValue.mainnetBech32}?amount=0.1',
      );
      expect((parsed as Bip21).network, Network.bitcoinMainnet);
      expect(parsed.sats, 10000000);
    });
  });
}
