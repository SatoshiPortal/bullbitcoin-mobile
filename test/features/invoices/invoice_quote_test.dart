import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';
import 'package:flutter_test/flutter_test.dart';

InvoiceQuote _quote({
  DateTime? createdAt,
  DateTime? expiresAt,
  int versionNumber = 1,
}) {
  final created = createdAt ?? DateTime.utc(2026, 1, 1, 12);
  return InvoiceQuote(
    invoiceId: InvoiceId('inv-1'),
    versionId: 'quote-$versionNumber',
    versionNumber: versionNumber,
    fiatFaceAmountMinor: 5000,
    fiatTargetAmountMinor: 2500,
    fiatCurrency: 'CAD',
    rateMinorPerBtc: 5000000,
    rateSource: 'test-rate',
    rateObservedAt: created.subtract(const Duration(seconds: 2)),
    rateFetchedAt: created.subtract(const Duration(seconds: 1)),
    rateFreshUntil: created.add(const Duration(minutes: 1)),
    createdAt: created,
    expiresAt: expiresAt ?? created.add(InvoiceQuote.lifetime),
    instruction: InvoiceLightningQuoteInstruction(
      quoteOfferId: 'offer-$versionNumber',
      pr: 'lnbc1050n1test',
      amount: InvoicePayerAmount(
        rail: PaymentMethod.lightning,
        merchantTargetAmountSat: 100000,
        payerAmountSat: 105000,
      ),
    ),
  );
}

void main() {
  test('quote has an exclusive five-minute usability window', () {
    final quote = _quote();

    expect(quote.timeUntilExpiry(quote.createdAt), const Duration(minutes: 5));
    expect(
      quote.isExpired(
        quote.expiresAt.subtract(const Duration(microseconds: 1)),
      ),
      isFalse,
    );
    expect(quote.isExpired(quote.expiresAt), isTrue);
  });

  test('rail availability preserves Lightning, Liquid, Bitcoin order', () {
    const availability = InvoiceQuoteRailAvailability(
      lightning: false,
      liquid: true,
      bitcoin: true,
    );

    expect(availability.firstAvailable, PaymentMethod.liquid);
    expect(availability.supports(PaymentMethod.lightning), isFalse);
    expect(availability.supports(PaymentMethod.btc), isTrue);
  });

  test('rejects a quote version whose window is not exactly five minutes', () {
    expect(
      () => _quote(expiresAt: DateTime.utc(2026, 1, 1, 12, 4, 59)),
      throwsArgumentError,
    );
  });
}
