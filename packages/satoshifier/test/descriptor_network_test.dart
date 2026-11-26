import 'package:flutter_test/flutter_test.dart';
import 'package:satoshifier/satoshifier.dart';
import 'package:satoshifier/_test_value.dart';

void main() {
  const fingerprint = '86241f88';

  group('descriptor network', () {
    // The coin type used to be the only signal, so a single wrong character in
    // the path silently produced a plausible wallet on the wrong chain: either
    // mainnet UTXOs that never appear, or real BTC sent to addresses derived
    // from a key the user only holds as a throwaway.
    test('rejects a mainnet key under a testnet path', () {
      expect(
        () => Descriptor.parse('[$fingerprint/84h/1h/0h]${TestValue.xpub}'),
        throwsA(anything),
      );
      expect(
        () => Descriptor.fromStrings(
          fingerprint: fingerprint,
          path: '84h/1h/0h',
          xpub: TestValue.xpub,
        ),
        throwsFormatException,
      );
    });

    test('rejects a testnet key under a mainnet path', () {
      expect(
        () => Descriptor.fromStrings(
          fingerprint: fingerprint,
          path: '84h/0h/0h',
          xpub: TestValue.xpubToTpub,
        ),
        throwsFormatException,
      );
    });

    test('accepts a consistent mainnet descriptor', () {
      final descriptor = Descriptor.fromStrings(
        fingerprint: fingerprint,
        path: '84h/0h/0h',
        xpub: TestValue.xpub,
      );
      expect(descriptor.network, Network.bitcoinMainnet);
    });

    test('accepts a consistent testnet descriptor', () {
      final descriptor = Descriptor.fromStrings(
        fingerprint: fingerprint,
        path: '84h/1h/0h',
        xpub: TestValue.xpubToTpub,
      );
      expect(descriptor.network, Network.bitcoinTestnet);
    });

    // Liquid is why the comparison is mainnet-versus-testnet rather than an
    // exact network match: coin type 1776 legitimately carries an xpub.
    test('accepts a liquid descriptor carrying an xpub', () {
      final descriptor = Descriptor.fromStrings(
        fingerprint: fingerprint,
        path: '84h/1776h/0h',
        xpub: TestValue.xpub,
      );
      expect(descriptor.network, Network.liquidMainnet);
    });
  });
}
