import 'package:bb_mobile/core/utils/msats.dart';
import 'package:flutter_test/flutter_test.dart';

/// BOLT11 denominates in millisatoshis and the pico-BTC multiplier makes
/// sub-satoshi amounts expressible, so converting to satoshis is lossy by
/// construction. Truncating discarded up to 999 msats per invoice and, below
/// one satoshi, reported zero — and amountSat is what wallet selection and the
/// amount shown to the user are built on.
void main() {
  group('msatsToSats', () {
    test('is exact on whole satoshis', () {
      expect(msatsToSats(0), 0);
      expect(msatsToSats(1000), 1);
      expect(msatsToSats(250000000), 250000);
    });

    test('never reports zero for a non-zero amount', () {
      expect(msatsToSats(1), 1);
      expect(msatsToSats(500), 1);
      expect(msatsToSats(999), 1);
    });

    test('rounds up rather than understating what is owed', () {
      expect(msatsToSats(1001), 2);
      expect(msatsToSats(1500), 2);
      expect(msatsToSats(1999), 2);
    });

    test('handles the BOLT11 spec sub-satoshi vector', () {
      // lnbc9678785340p... — 0.00967878534 BTC, i.e. 967_878.534 sats.
      // Truncation reported 967_878 and lost 534 msats.
      expect(msatsToSats(967878534), 967879);
    });

    test('treats a negative amount as zero rather than a negative balance', () {
      expect(msatsToSats(-1), 0);
    });
  });
}
