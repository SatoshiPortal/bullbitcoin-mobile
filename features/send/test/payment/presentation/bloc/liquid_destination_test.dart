import 'package:flutter_test/flutter_test.dart';
import 'package:rust_bindings/lwk.dart' as lwk;
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:satoshifier/payment_request.dart';
import 'package:send/src/payment/presentation/bloc/send_state.dart';

void main() {
  setUpAll(BullSdk.init);
  tearDownAll(BullSdk.dispose);

  test('Send flags only the unconfidential form of a parsed Liquid destination', () async {
    final pair = await lwk.Address.addressFromScript(
      network: lwk.LiquidNetwork.mainnet,
      script: '0014${'22' * 20}',
      blindingKey:
          '0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798',
    );
    for (final (address, warns) in [
      (pair.standard, true),
      (pair.confidential, false),
    ]) {
      final state = SendState(
        sendType: SendType.liquid,
        paymentRequest: await PaymentRequest.parse(address),
      );
      expect(state.isUnconfidentialLiquidDestination, warns);
    }
  });
}
