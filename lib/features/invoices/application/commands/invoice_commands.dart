import 'package:bb_mobile/features/invoices/domain/primitives/invoice_status.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';

/// The intent to create a wallet-origin invoice. Amount is one-of: EITHER
/// [amountSat] XOR ([fiatAmountMinor] + [fiatCurrency]).
///
/// [linkToPageNym] stays null in v1 (DG-I1 unlinked-only); it is carried so the
/// create path is linked-capable when the decision later flips. [privateMemo]
/// is stored LOCALLY as address labels after success and NEVER sent to the
/// server (§3.14).
class CreateInvoiceCommand {
  final int? amountSat;
  final int? fiatAmountMinor;
  final String? fiatCurrency;
  final String? publicDescription;
  final String? recipientName;
  final String? invoiceNumber;
  final bool acceptBtc;
  final bool acceptLn;
  final bool acceptLiquid;
  final DateTime expiresAt;
  final String? linkToPageNym;
  final String? privateMemo;

  const CreateInvoiceCommand({
    this.amountSat,
    this.fiatAmountMinor,
    this.fiatCurrency,
    this.publicDescription,
    this.recipientName,
    this.invoiceNumber,
    required this.acceptBtc,
    required this.acceptLn,
    required this.acceptLiquid,
    required this.expiresAt,
    this.linkToPageNym,
    this.privateMemo,
  });

  bool get hasSatAmount => amountSat != null;
  bool get hasFiatAmount => fiatAmountMinor != null && fiatCurrency != null;
  bool get hasExactlyOneAmount => hasSatAmount != hasFiatAmount;
  bool get hasAnyRail => acceptBtc || acceptLn || acceptLiquid;
  bool get needsLiquidAddress => acceptLn || acceptLiquid;
}

/// The intent to cancel an invoice. [nymOwner] mirrors the invoice's owner nym
/// (null for the unlinked v1 invoices) so the signed cancel targets the right
/// endpoint.
class CancelInvoiceCommand {
  final InvoiceId invoiceId;
  final String? nymOwner;

  const CancelInvoiceCommand({required this.invoiceId, this.nymOwner});
}

/// The intent to list the signing npub's invoices. [status] is an optional
/// server-side filter (v1 filters client-side, so this is usually null).
class ListInvoicesCommand {
  final int page;
  final int pageSize;
  final InvoiceStatus? status;

  const ListInvoicesCommand({
    this.page = 1,
    this.pageSize = 100,
    this.status,
  });
}
