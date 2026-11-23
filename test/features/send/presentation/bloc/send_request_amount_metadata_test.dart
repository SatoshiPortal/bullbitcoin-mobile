import 'package:primitives/primitives.dart' show BitcoinNetwork;
import 'package:satoshifier/payment_request.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only a positive primary BIP21 amount locks the amount input', () {
    for (final amount in <int?>[null, 0, 2500]) {
      final state = SendState(
        paymentRequest: PaymentRequest.bip21(
          network: BitcoinNetwork.mainnet,
          uri: 'bitcoin:address',
          address: 'address',
          amountSat: amount,
        ),
      );
      expect(state.hasFixedRequestAmount, amount != null && amount > 0);
    }
    expect(const SendState().hasFixedRequestAmount, isFalse);
    expect(
      const SendState(
        paymentRequest: PaymentRequest.bitcoin(
          address: 'address',
          isTestnet: false,
        ),
      ).hasFixedRequestAmount,
      isFalse,
    );
  });

  test('a new Send session has no QR amount provenance', () {
    expect(const SendState().qrAmountRecipientIds, isEmpty);
  });
}
