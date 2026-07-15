import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart'
    show BullnymAuthSigner;
import 'package:bb_mobile/features/invoices/application/commands/invoice_commands.dart';
import 'package:bb_mobile/features/invoices/application/results/invoice_results.dart';
import 'package:bb_mobile/features/invoices/domain/entities/prepared_private_invoice_create.dart';
import 'package:bb_mobile/features/invoices/domain/entities/invoice_status_snapshot.dart';
import 'package:bb_mobile/features/invoices/domain/entities/invoice_fallback_supervision.dart';
import 'package:bb_mobile/features/invoices/domain/invoices_failure.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';
import 'package:meta/meta.dart';

/// The invoices feature's view of the pay-service. Implementations wrap the
/// shared `bullnym` client, map its raw exceptions to [InvoicesFailure], and
/// return domain types only — a Bullnym DTO never crosses this boundary.
///
/// The payout addresses are supplied by the caller (the create usecase); this
/// port performs NO wallet derivation.
abstract interface class InvoicesPayServicePort {
  @useResult
  Future<Result<CreateInvoiceResult, InvoicesFailure>> createInvoice({
    required BullnymAuthSigner signer,
    required PreparedPrivateInvoiceCreate operation,
  });

  @useResult
  Future<Result<CancelInvoiceResult, InvoicesFailure>> cancelInvoice({
    required BullnymAuthSigner signer,
    required CancelInvoiceCommand command,
  });

  @useResult
  Future<Result<ListInvoicesResult, InvoicesFailure>> listInvoices({
    required BullnymAuthSigner signer,
    required ListInvoicesCommand command,
  });

  /// Signed, npub-wide and read-only automatic-fallback supervision.
  @useResult
  Future<Result<InvoiceFallbackOverview, InvoicesFailure>>
  listFallbackSupervision({required BullnymAuthSigner signer});

  /// UNSIGNED public status poll by id (§3.12).
  @useResult
  Future<Result<InvoiceStatusSnapshot, InvoicesFailure>> getInvoiceStatus(
    InvoiceId invoiceId,
  );
}
