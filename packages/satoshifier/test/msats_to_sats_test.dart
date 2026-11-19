import 'package:flutter_test/flutter_test.dart';
import 'package:satoshifier/utils/utils.dart';

/// BOLT11 denominates amounts in millisatoshis, and the pico-BTC multiplier
/// makes sub-satoshi amounts expressible, so converting to satoshis is lossy
/// by construction. Truncating discards up to 999 msats per invoice and, for
/// an invoice below one satoshi, reports zero — which reads as an amountless
/// invoice rather than a small one.
void main() {
  group('msatsToSats', () {
    test('is exact on whole satoshis', () {
      expect(Utils.msatsToSats(0), 0);
      expect(Utils.msatsToSats(1000), 1);
      expect(Utils.msatsToSats(1000000), 1000);
    });

    test('never reports zero for a non-zero amount', () {
      expect(Utils.msatsToSats(1), 1);
      expect(Utils.msatsToSats(500), 1);
      expect(Utils.msatsToSats(999), 1);
    });

    test('rounds up rather than understating what is owed', () {
      expect(Utils.msatsToSats(1001), 2);
      expect(Utils.msatsToSats(1500), 2);
      expect(Utils.msatsToSats(1999), 2);
    });

    test('handles the BOLT11 spec sub-satoshi vector', () {
      // lnbc9678785340p... — 0.00967878534 BTC, i.e. 967_878.534 sats.
      // Truncation reported 967_878 and lost 534 msats.
      expect(Utils.msatsToSats(967878534), 967879);
    });

    test('rejects a negative amount', () {
      expect(() => Utils.msatsToSats(-1), throwsFormatException);
    });
  });
}
