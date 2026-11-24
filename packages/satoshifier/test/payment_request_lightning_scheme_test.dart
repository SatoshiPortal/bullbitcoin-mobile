import 'package:flutter_test/flutter_test.dart';
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:satoshifier/_test_value.dart';
import 'package:satoshifier/payment_request.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(BullSdk.init);
  for (final scheme in ['lightning', 'LIGHTNING', 'LiGhTnInG']) {
    test('$scheme: keeps the standalone LNURL payload', () async {
      final payload = TestValue.lnurlUppercase;
      final request = await PaymentRequest.parse('$scheme:$payload');
      expect(request, isA<LnAddressPaymentRequest>());
      expect((request as LnAddressPaymentRequest).address, payload);
    });

    test('$scheme: parses a standalone BOLT11 invoice', () async {
      final payload = TestValue.bolt11Lowercase;
      final request = await PaymentRequest.parse('$scheme:$payload');
      expect(request, isA<Bolt11PaymentRequest>());
      expect((request as Bolt11PaymentRequest).invoice, payload);
      expect(request.amountSat, greaterThan(0));
    });
  }

  test('a doubled Lightning scheme is rejected', () async {
    await expectLater(
      PaymentRequest.parse('lightning:lightning:${TestValue.bolt11Lowercase}'),
      throwsA('Invalid payment request'),
    );
  });
}
