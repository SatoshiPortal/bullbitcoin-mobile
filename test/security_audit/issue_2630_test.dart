// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2630
// Finding: BIP21 labels can contain control characters and are returned unchanged.
// Regression test for the fix.

import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2630 payment-request labels', () {
    test('BIP21 label strips control characters', () async {
      const address = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';
      final result = await PaymentRequest.parse(
        'bitcoin:$address?label=first%0Asecond%09hidden',
      );

      expect(result, isA<Bip21PaymentRequest>());
      expect((result as Bip21PaymentRequest).label, 'firstsecondhidden');
    });
  });
}
