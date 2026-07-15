// Wire DTOs for the signed recipient-invoice endpoints (server
// `src/invoice.rs`). JSON keys mirror the server EXACTLY (snake_case, incl.
// the `pageSize` query/response rename the server pins in `ListSignedQuery` /
// `ListInvoicesResponse`). These are data-layer shapes only; the `invoices`
// feature maps them to its own domain entities and never re-exports them.

/// The raw `invoice-create` field values, in the server's storage order. The
/// signer emits every field (absent optionals as the empty string) so the
/// signed byte layout is stable; this object is the single source those
/// ordered fields are built from (`buildInvoiceCreatePayloadFields`).
class BullnymCreateInvoiceFields {
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
}

/// The signed-create response (`CreateSignedResponse`): only the id and the
/// fragmentless construction URL. Pricing/status live on the separate status
/// shape; Mobile appends the private viewing-key fragment locally.
class BullnymCreateInvoiceResponse {
  final String invoiceId;
  final String invoiceUrl;

  const BullnymCreateInvoiceResponse({
    required this.invoiceId,
    required this.invoiceUrl,
  });
}

/// The signed-cancel response (`CancelResponse`): the id and the final status
/// the server settled on (`cancelled`, or the pre-existing terminal status).
class BullnymCancelInvoiceResponse {
  final String invoiceId;
  final String status;

  const BullnymCancelInvoiceResponse({
    required this.invoiceId,
    required this.status,
  });
}

/// One row of the npub-keyed list (`InvoiceListItem`). `nymOwner` is null for
/// unlinked invoices; the `paid*` fields are populated only once paid.
class BullnymInvoiceListItem {
  final String id;
  final String? nymOwner;
  final String origin;
  final String status;
  final String? presentationStatus;
  final String pricingMode;
  final String settlementStatus;
  final int amountSat;
  final int remainingAmountSat;
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
  });
}

/// One raw Bitcoin-chain observation in the public invoice-status response.
/// Interpretation belongs to the invoices settlement domain; Bullnym only
/// preserves the deployed server contract and validates its wire types.
class BullnymBitcoinDirectObservation {
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

/// The npub-keyed list response (`ListInvoicesResponse`). `pageSize` keeps the
/// server's camelCase wire key.
class BullnymListInvoicesResponse {
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

/// The public status shape (`InvoiceStatusResponse`, unsigned GET by id). Kept
/// deliberately separate from the list/create shapes (server design): callers
/// merge explicitly, they never conflate the two.
class BullnymInvoiceStatus {
  final String status;
  final String? presentationStatus;
  final String pricingMode;
  final String settlementStatus;
  final int amountSat;
  final int? fiatAmountMinor;
  final String? fiatCurrency;
  final int remainingAmountSat;
  final int paymentToleranceSat;
  final int? rateMinorPerBtc;
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

  const BullnymInvoiceStatus({
    required this.status,
    this.presentationStatus,
    required this.pricingMode,
    required this.settlementStatus,
    required this.amountSat,
    this.fiatAmountMinor,
    this.fiatCurrency,
    required this.remainingAmountSat,
    required this.paymentToleranceSat,
    this.rateMinorPerBtc,
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
  });
}
