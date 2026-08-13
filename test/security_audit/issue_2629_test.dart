// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2629
// Finding: unanchored Lightning-address regex extracts an email-like substring from a Bitcoin URI.
// Regression test for the fix.

import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2629 malformed Bitcoin URI', () {
    test(
      'malformed Bitcoin URI is not reclassified as Lightning address',
      () async {
        const input = 'bitcoin:not-an-address?label=pay%20alice@example.com';
        await expectLater(PaymentRequest.parse(input), throwsA(anything));
      },
    );
  });
}
