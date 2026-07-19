import 'package:bb_mobile/features/bullnym/domain/bullnym_invoice.dart';

// Deployed Bullnym invoice action names (server `src/invoice.rs`
// ACTION_CREATE / ACTION_CANCEL / ACTION_LIST). These ride the SAME
// `bullpay-la-v2` signer as the donation-page actions; renaming any of them is
// a breaking protocol change.
const String bullpayActionInvoiceCreate = 'invoice-create';
const String bullpayActionInvoiceCancel = 'invoice-cancel';
const String bullpayActionInvoiceList = 'invoice-list';

/// The signed `invoice-create` payload fields, in the server's FIXED order
/// (`create_payload_fields` in `src/invoice.rs`). All 12 fields are ALWAYS
/// emitted: absent optionals become the empty string (never skipped), so the
/// NUL-separator count is invariant; booleans serialize as `"true"`/`"false"`
/// (Rust `bool::to_string`), never `1`/`0`; numeric fields are decimal
/// (`i64::to_string`). Reordering, dropping, or `1`/`0`-ing any field breaks
/// the server signature check — the golden vectors in the contract test are the
/// tripwire.
List<String> buildInvoiceCreatePayloadFields(BullnymCreateInvoiceFields f) {
  return [
    f.amountSat?.toString() ?? '',
    f.fiatAmountMinor?.toString() ?? '',
    f.fiatCurrency ?? '',
    f.clientRequestId,
    f.presentationEnvelope,
    f.acceptBtc.toString(),
    f.acceptLn.toString(),
    f.acceptLiquid.toString(),
    f.bitcoinAddress ?? '',
    f.liquidAddress ?? '',
    f.liquidBlindingKeyHex ?? '',
    f.expiresAtUnix?.toString() ?? '',
  ];
}

/// The signed `invoice-cancel` payload: `[invoice_id]` only
/// (`cancel_payload_fields`).
List<String> buildInvoiceCancelPayloadFields(String invoiceId) => [invoiceId];

/// The signed `invoice-list` payload: `[page, pageSize, status_or_empty]`
/// (`list_payload_fields`). The `nym_or_empty` slot is ALWAYS empty for the
/// list — the action is npub-wide, not per-nym (server comment).
List<String> buildInvoiceListPayloadFields({
  required int page,
  required int pageSize,
  String? status,
}) {
  return [page.toString(), pageSize.toString(), status ?? ''];
}
