import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart'
    show BullnymAuthSigner;
import 'package:bb_mobile/features/invoices/application/commands/invoice_commands.dart';
import 'package:bb_mobile/features/invoices/application/results/invoice_results.dart';
import 'package:bb_mobile/features/invoices/domain/entities/invoice_status_snapshot.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';

/// The invoices feature's view of the pay-service. Implementations wrap the
/// shared `bullnym` client, map its `BullnymException` to `InvoicesException`,
/// and return DOMAIN types only — a bullnym DTO never crosses this boundary.
///
/// The payout addresses are supplied by the caller (the create usecase); this
/// port performs NO wallet derivation.
abstract interface class InvoicesPayServicePort {
  Future<CreateInvoiceResult> createInvoice({
    required BullnymAuthSigner signer,
    required CreateInvoiceCommand command,
    String? bitcoinAddress,
    String? liquidAddress,
    String? liquidBlindingKeyHex,
  });

  Future<CancelInvoiceResult> cancelInvoice({
    required BullnymAuthSigner signer,
    required CancelInvoiceCommand command,
  });

  Future<ListInvoicesResult> listInvoices({
    required BullnymAuthSigner signer,
    required ListInvoicesCommand command,
  });

  /// UNSIGNED public status poll by id (§3.12).
  Future<InvoiceStatusSnapshot> getInvoiceStatus(InvoiceId invoiceId);
}
