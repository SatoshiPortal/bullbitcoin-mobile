import 'package:flutter_test/flutter_test.dart';
import 'package:satoshifier/satoshifier.dart';
import 'package:satoshifier/_test_value.dart';

void main() {
  Future<int> satsFor(String amount) async {
    final parsed = await Bip21Parser.parse(
      'bitcoin:${TestValue.mainnetBech32}?amount=$amount',
    );
    return (parsed as Bip21).sats;
  }

  group('Bip21Parser amount', () {
    // The decoded amount is a double, and double.toString() switches to
    // scientific notation below 1e-6. Every amount under 1000 sats used to
    // render as "1e-8"/"5e-7" and throw inside btcToSats — silently, since
    // tryParse swallows it.
    test('parses a one-satoshi amount', () async {
      expect(await satsFor('0.00000001'), 1);
    });

    test('parses amounts across the scientific-notation boundary', () async {
      expect(await satsFor('0.0000005'), 50);
      expect(await satsFor('0.00000099'), 99);
      expect(await satsFor('0.000001'), 100);
    });

    test('leaves ordinary amounts unchanged', () async {
      expect(await satsFor('0.00001'), 1000);
      expect(await satsFor('0.1'), 10000000);
      expect(await satsFor('20.3'), 2030000000);
    });

    test('keeps full satoshi precision on a long decimal', () async {
      expect(await satsFor('0.12345678'), 12345678);
    });

    test('a URI without an amount is zero, not an error', () async {
      final parsed = await Bip21Parser.parse(
        'bitcoin:${TestValue.mainnetBech32}',
      );
      expect((parsed as Bip21).sats, 0);
    });

    // QR codes often carry the whole URI uppercased for alphanumeric mode,
    // which uppercases the query key too.
    test('reads the amount from an uppercased URI', () async {
      final parsed = await Bip21Parser.parse(
        'BITCOIN:${TestValue.mainnetBech32.toUpperCase()}?AMOUNT=0.00000001',
      );
      expect((parsed as Bip21).sats, 1);
    });
  });
}
