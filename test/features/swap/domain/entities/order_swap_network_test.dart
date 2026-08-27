import 'package:bb_mobile/core/primitives/payment_network.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_network.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converts every OrderSwapNetwork to its PaymentNetwork counterpart', () {
    expect(OrderSwapNetwork.bitcoin.toPaymentNetwork, PaymentNetwork.bitcoin);
    expect(OrderSwapNetwork.liquid.toPaymentNetwork, PaymentNetwork.liquid);
    expect(
      OrderSwapNetwork.lightning.toPaymentNetwork,
      PaymentNetwork.lightning,
    );
  });
}
