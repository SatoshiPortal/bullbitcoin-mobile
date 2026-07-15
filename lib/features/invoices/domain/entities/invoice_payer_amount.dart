import 'package:bb_mobile/features/invoices/domain/primitives/payment_method.dart';

/// Exact fixed-checkout economics for one currently payable rail.
///
/// [merchantTargetAmountSat] is the invoice value this instruction must credit
/// (the current remainder after a partial payment). [payerAmountSat] is the
/// exact principal the payer must send. Keeping both values prevents checkout
/// gross-up from mutating the invoice's merchant face value.
class InvoicePayerAmount {
  final PaymentMethod rail;
  final int merchantTargetAmountSat;
  final int payerAmountSat;

  InvoicePayerAmount({
    required this.rail,
    required this.merchantTargetAmountSat,
    required this.payerAmountSat,
  }) {
    if (merchantTargetAmountSat <= 0 || payerAmountSat <= 0) {
      throw ArgumentError('Invoice payer amounts must be positive');
    }
    if (payerAmountSat < merchantTargetAmountSat) {
      throw ArgumentError(
        'The payer amount cannot be less than the merchant target',
      );
    }
  }

  /// Provider and payment-network costs paid above the merchant target.
  int get checkoutCostSat => payerAmountSat - merchantTargetAmountSat;
}
