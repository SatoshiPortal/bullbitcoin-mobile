import 'package:bb_mobile/features/invoices/domain/entities/invoice_payer_amount.dart';
import 'package:bb_mobile/features/invoices/domain/primitives/payment_method.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('derives checkout costs without changing the merchant target', () {
    final amount = InvoicePayerAmount(
      rail: PaymentMethod.btc,
      merchantTargetAmountSat: 100000,
      payerAmountSat: 105000,
    );

    expect(amount.merchantTargetAmountSat, 100000);
    expect(amount.payerAmountSat, 105000);
    expect(amount.checkoutCostSat, 5000);
  });

  test('accepts a no-gross-up direct Liquid instruction', () {
    final amount = InvoicePayerAmount(
      rail: PaymentMethod.liquid,
      merchantTargetAmountSat: 100000,
      payerAmountSat: 100000,
    );

    expect(amount.checkoutCostSat, 0);
  });

  test('rejects zero, negative, and under-target payer amounts', () {
    for (final values in [
      (merchant: 0, payer: 1),
      (merchant: 1, payer: 0),
      (merchant: 1000, payer: 999),
    ]) {
      expect(
        () => InvoicePayerAmount(
          rail: PaymentMethod.lightning,
          merchantTargetAmountSat: values.merchant,
          payerAmountSat: values.payer,
        ),
        throwsArgumentError,
      );
    }
  });
}
