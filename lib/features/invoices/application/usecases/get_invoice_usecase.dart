import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_pay_service_port.dart';
import 'package:bb_mobile/features/invoices/domain/entities/invoice_status_snapshot.dart';
import 'package:bb_mobile/features/invoices/domain/entities/invoice_quote.dart';
import 'package:bb_mobile/features/invoices/domain/primitives/payment_method.dart';
import 'package:bb_mobile/features/invoices/domain/invoices_failure.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';
import 'package:meta/meta.dart';

/// Fetches the public status snapshot for an invoice. The status endpoint is
/// UNSIGNED and keyed by id (§3.12) — no signer/handle is resolved here.
class GetInvoiceUsecase {
  final InvoicesPayServicePort _payService;

  const GetInvoiceUsecase({required this._payService});

  @useResult
  Future<Result<InvoiceStatusSnapshot, InvoicesFailure>> execute(
    InvoiceId invoiceId,
  ) => _payService.getInvoiceStatus(invoiceId);

  @useResult
  Future<Result<InvoiceQuote, InvoicesFailure>> quote({
    required InvoiceId invoiceId,
    required PaymentMethod rail,
  }) => _payService.getInvoiceQuote(invoiceId: invoiceId, rail: rail);
}
