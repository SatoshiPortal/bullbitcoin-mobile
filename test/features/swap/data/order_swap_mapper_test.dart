import 'package:bb_mobile/features/swap/data/mappers/order_swap_mapper.dart';
import 'package:bb_mobile/features/swap/data/models/order_swap_model.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const methods = {
    'Bitcoin On-Chain': OrderSwapNetwork.bitcoin,
    'Liquid Network': OrderSwapNetwork.liquid,
    'Lightning Invoice (BOLT11)': OrderSwapNetwork.lightning,
  };

  test('maps every measured payin and payout method', () {
    for (final input in methods.entries) {
      for (final output in methods.entries) {
        if (input.key == output.key) continue;

        final order = _model(
          payinMethod: input.key,
          payoutMethod: output.key,
        ).toEntity();

        expect(order.inNetwork, input.value);
        expect(order.outNetwork, output.value);
      }
    }
  });

  test('recognizes a payin under manual review', () {
    final order = _model(
      payinMethod: 'Bitcoin On-Chain',
      payoutMethod: 'Liquid Network',
      payinStatus: 'Under review',
    ).toEntity();

    expect(order.requiresManualReview, isTrue);
  });
}

OrderSwapModel _model({
  required String payinMethod,
  required String payoutMethod,
  String payinStatus = 'Awaiting payment',
}) => OrderSwapModel(
  orderId: 'order-1',
  orderNumber: 1,
  payinAmount: '0.00105',
  payoutAmount: '0.0010395',
  payinCurrency: 'BTC',
  payoutCurrency: 'LBTC',
  payinMethod: payinMethod,
  payoutMethod: payoutMethod,
  orderType: 'Swap',
  orderStatus: 'In_pending',
  payinStatus: payinStatus,
  payoutStatus: 'Not started',
  messageCode: 'PAYMENT_NOT_DETECTED',
  createdAt: DateTime.utc(2026, 8, 6, 18),
  confirmationDeadline: DateTime.utc(2026, 8, 6, 18, 5),
);
