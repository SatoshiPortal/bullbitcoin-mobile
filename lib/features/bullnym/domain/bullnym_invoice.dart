import 'dart:convert';

import 'package:bb_mobile/features/bullnym/domain/bullnym_invoice_quote.dart';

const _privateInvoicePresentationBytes = 1 + 12 + 4096 + 16;

final _uuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

final class BullnymCreateInvoiceFields {
  final int? amountSat;
  final int? fiatAmountMinor;
  final String? fiatCurrency;
  final String clientRequestId;
  final String presentationEnvelope;
  final bool acceptBtc;
  final bool acceptLn;
  final bool acceptLiquid;
  final String? bitcoinAddress;
  final String? liquidAddress;
  final String? liquidBlindingKeyHex;
  final int? expiresAtUnix;

  const BullnymCreateInvoiceFields({
    this.amountSat,
    this.fiatAmountMinor,
    this.fiatCurrency,
    required this.clientRequestId,
    required this.presentationEnvelope,
    required this.acceptBtc,
    required this.acceptLn,
    required this.acceptLiquid,
    this.bitcoinAddress,
    this.liquidAddress,
    this.liquidBlindingKeyHex,
    this.expiresAtUnix,
  });

  bool get hasValidPrivatePresentation {
    if (!_uuidV4Pattern.hasMatch(clientRequestId)) return false;
    try {
      final bytes = base64Url.decode(presentationEnvelope);
      return bytes.length == _privateInvoicePresentationBytes &&
          bytes.first == 1 &&
          base64Url.encode(bytes) == presentationEnvelope;
    } on FormatException {
      return false;
    }
  }
}

final class BullnymCreateInvoiceResponse {
  final String invoiceId;
  final String invoiceUrl;

  const BullnymCreateInvoiceResponse(this.invoiceId, this.invoiceUrl);
}

final class BullnymCancelInvoiceResponse {
  final String invoiceId;
  final String status;

  const BullnymCancelInvoiceResponse(this.invoiceId, this.status);
}

final class BullnymMerchantFiatPaymentSummary {
  final String currency;
  final int targetAmountMinor;
  final int creditedAmountMinor;
  final int remainingAmountMinor;

  const BullnymMerchantFiatPaymentSummary({
    required this.currency,
    required this.targetAmountMinor,
    required this.creditedAmountMinor,
    required this.remainingAmountMinor,
  });
}

final class BullnymMerchantPaymentSummary {
  final int observedAmountSat;
  final int creditedAmountSat;
  final int remainingAmountSat;
  final int excessAmountSat;
  final int logicalPaymentCount;
  final bool multiplePayments;
  final int latePaymentCount;
  final bool hasLatePayment;
  final int? firstPaymentAtUnix;
  final int? lastPaymentAtUnix;
  final bool acceptingPayments;
  final bool topUpAllowed;
  final bool requiresMerchantAction;
  final List<String> attentionReasons;
  final BullnymMerchantFiatPaymentSummary? fiat;

  const BullnymMerchantPaymentSummary({
    required this.observedAmountSat,
    required this.creditedAmountSat,
    required this.remainingAmountSat,
    required this.excessAmountSat,
    required this.logicalPaymentCount,
    required this.multiplePayments,
    required this.latePaymentCount,
    required this.hasLatePayment,
    this.firstPaymentAtUnix,
    this.lastPaymentAtUnix,
    required this.acceptingPayments,
    required this.topUpAllowed,
    required this.requiresMerchantAction,
    required this.attentionReasons,
    this.fiat,
  });
}

final class BullnymInvoiceListItem {
  final String id;
  final String? nymOwner;
  final String origin;
  final String status;
  final String? presentationStatus;
  final String pricingMode;
  final String settlementStatus;
  final int amountSat;
  final int remainingAmountSat;
  final bool? acceptingPayments;
  final bool? topUpAllowed;
  final int? fiatAmountMinor;
  final String? fiatCurrency;
  final String? memo;
  final bool acceptBtc;
  final bool acceptLn;
  final bool acceptLiquid;
  final String? bitcoinAddress;
  final String? liquidAddress;
  final int createdAtUnix;
  final int expiresAtUnix;
  final String? paidVia;
  final int? paidAtUnix;
  final int? paidAmountSat;
  final BullnymMerchantPaymentSummary? paymentSummary;

  const BullnymInvoiceListItem({
    required this.id,
    this.nymOwner,
    required this.origin,
    required this.status,
    this.presentationStatus,
    required this.pricingMode,
    required this.settlementStatus,
    required this.amountSat,
    required this.remainingAmountSat,
    this.acceptingPayments,
    this.topUpAllowed,
    this.fiatAmountMinor,
    this.fiatCurrency,
    this.memo,
    required this.acceptBtc,
    required this.acceptLn,
    required this.acceptLiquid,
    this.bitcoinAddress,
    this.liquidAddress,
    required this.createdAtUnix,
    required this.expiresAtUnix,
    this.paidVia,
    this.paidAtUnix,
    this.paidAmountSat,
    this.paymentSummary,
  });
}

final class BullnymBitcoinDirectObservation {
  final String source;
  final String rail;
  final String txid;
  final int vout;
  final String address;
  final int amountSat;
  final int confirmations;
  final int? blockHeight;
  final String state;
  final int firstSeenAtUnix;
  final int lastSeenAtUnix;

  const BullnymBitcoinDirectObservation({
    required this.source,
    required this.rail,
    required this.txid,
    required this.vout,
    required this.address,
    required this.amountSat,
    required this.confirmations,
    this.blockHeight,
    required this.state,
    required this.firstSeenAtUnix,
    required this.lastSeenAtUnix,
  });
}

final class BullnymListInvoicesResponse {
  final List<BullnymInvoiceListItem> invoices;
  final int page;
  final int pageSize;
  final bool hasMore;

  const BullnymListInvoicesResponse({
    required this.invoices,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });
}

final class BullnymInvoiceStatus {
  final String status;
  final String? presentationStatus;
  final String pricingMode;
  final String settlementStatus;
  final int amountSat;
  final int? fiatAmountMinor;
  final String? fiatCurrency;
  final int remainingAmountSat;
  final bool? acceptingPayments;
  final bool? topUpAllowed;
  final int paymentToleranceSat;
  final int? rateMinorPerBtc;
  final int? creationRateMinorPerBtc;
  final int rateLocksUntilUnix;
  final int expiresAtUnix;
  final String? paidVia;
  final int? paidAtUnix;
  final int? paidAmountSat;
  final String? lightningPr;
  final int? lightningAmountSat;
  final String? liquidAddress;
  final int? liquidAmountSat;
  final String? bitcoinAddress;
  final String? bitcoinChainAddress;
  final String? bitcoinChainBip21;
  final int? bitcoinChainAmountSat;
  final bool acceptBtc;
  final bool acceptLn;
  final bool acceptLiquid;
  final List<BullnymBitcoinDirectObservation> bitcoinDirectObservations;
  final BullnymPayerQuoteRailAvailability? quoteRailAvailability;

  const BullnymInvoiceStatus({
    required this.status,
    this.presentationStatus,
    required this.pricingMode,
    required this.settlementStatus,
    required this.amountSat,
    this.fiatAmountMinor,
    this.fiatCurrency,
    required this.remainingAmountSat,
    this.acceptingPayments,
    this.topUpAllowed,
    required this.paymentToleranceSat,
    this.rateMinorPerBtc,
    this.creationRateMinorPerBtc,
    required this.rateLocksUntilUnix,
    required this.expiresAtUnix,
    this.paidVia,
    this.paidAtUnix,
    this.paidAmountSat,
    this.lightningPr,
    this.lightningAmountSat,
    this.liquidAddress,
    this.liquidAmountSat,
    this.bitcoinAddress,
    this.bitcoinChainAddress,
    this.bitcoinChainBip21,
    this.bitcoinChainAmountSat,
    required this.acceptBtc,
    required this.acceptLn,
    required this.acceptLiquid,
    required this.bitcoinDirectObservations,
    this.quoteRailAvailability,
  });
}
