import 'package:bb_mobile/features/invoices/domain/entities/invoice_payer_amount.dart';
import 'package:bb_mobile/features/invoices/domain/primitives/payment_method.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';

class InvoiceQuoteRailAvailability {
  final bool lightning;
  final bool liquid;
  final bool bitcoin;

  const InvoiceQuoteRailAvailability({
    required this.lightning,
    required this.liquid,
    required this.bitcoin,
  });

  bool supports(PaymentMethod rail) => switch (rail) {
    PaymentMethod.lightning => lightning,
    PaymentMethod.liquid => liquid,
    PaymentMethod.btc => bitcoin,
  };

  PaymentMethod? get firstAvailable {
    if (lightning) return PaymentMethod.lightning;
    if (liquid) return PaymentMethod.liquid;
    if (bitcoin) return PaymentMethod.btc;
    return null;
  }
}

sealed class InvoiceQuoteInstruction {
  final InvoicePayerAmount amount;

  const InvoiceQuoteInstruction({required this.amount});

  PaymentMethod get rail => amount.rail;
  String get copyPayload;
}

final class InvoiceLightningQuoteInstruction extends InvoiceQuoteInstruction {
  final String quoteOfferId;
  final String pr;

  const InvoiceLightningQuoteInstruction({
    required this.quoteOfferId,
    required this.pr,
    required super.amount,
  });

  @override
  String get copyPayload => pr;
}

final class InvoiceLiquidQuoteInstruction extends InvoiceQuoteInstruction {
  final String address;

  const InvoiceLiquidQuoteInstruction({
    required this.address,
    required super.amount,
  });

  @override
  String get copyPayload => address;
}

final class InvoiceBitcoinQuoteInstruction extends InvoiceQuoteInstruction {
  final String? quoteOfferId;
  final String address;
  final String bip21;

  const InvoiceBitcoinQuoteInstruction({
    this.quoteOfferId,
    required this.address,
    required this.bip21,
    required super.amount,
  });

  bool get isProviderBacked => quoteOfferId != null;

  @override
  String get copyPayload => bip21;
}

class InvoiceQuote {
  static const lifetime = Duration(minutes: 5);

  final InvoiceId invoiceId;
  final String versionId;
  final int versionNumber;
  final int fiatFaceAmountMinor;
  final int fiatTargetAmountMinor;
  final String fiatCurrency;
  final int rateMinorPerBtc;
  final String rateSource;
  final DateTime rateObservedAt;
  final DateTime rateFetchedAt;
  final DateTime rateFreshUntil;
  final DateTime createdAt;
  final DateTime expiresAt;
  final InvoiceQuoteInstruction instruction;

  InvoiceQuote({
    required this.invoiceId,
    required this.versionId,
    required this.versionNumber,
    required this.fiatFaceAmountMinor,
    required this.fiatTargetAmountMinor,
    required this.fiatCurrency,
    required this.rateMinorPerBtc,
    required this.rateSource,
    required this.rateObservedAt,
    required this.rateFetchedAt,
    required this.rateFreshUntil,
    required this.createdAt,
    required this.expiresAt,
    required this.instruction,
  }) {
    if (versionId.trim().isEmpty ||
        fiatCurrency.trim().isEmpty ||
        rateSource.trim().isEmpty ||
        versionNumber <= 0 ||
        fiatFaceAmountMinor <= 0 ||
        fiatTargetAmountMinor <= 0 ||
        fiatTargetAmountMinor > fiatFaceAmountMinor ||
        rateMinorPerBtc <= 0 ||
        expiresAt.difference(createdAt) != lifetime ||
        !rateFreshUntil.isAfter(rateObservedAt) ||
        !rateFreshUntil.isAfter(rateFetchedAt)) {
      throw ArgumentError('Invoice quote evidence is inconsistent');
    }
  }

  PaymentMethod get selectedRail => instruction.rail;

  bool isExpired(DateTime now) => !expiresAt.isAfter(now.toUtc());

  Duration timeUntilExpiry(DateTime now) {
    final remaining = expiresAt.difference(now.toUtc());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}
