import 'package:primitives/primitives.dart' show PaymentNetwork;
import 'package:swaps/order_swaps.dart';
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
