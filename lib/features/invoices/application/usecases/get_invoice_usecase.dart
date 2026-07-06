import 'package:bb_mobile/features/invoices/application/ports/invoices_pay_service_port.dart';
import 'package:bb_mobile/features/invoices/domain/entities/invoice_status_snapshot.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';

/// Fetches the public status snapshot for an invoice. The status endpoint is
/// UNSIGNED and keyed by id (§3.12) — no signer/handle is resolved here.
class GetInvoiceUsecase {
  final InvoicesPayServicePort _payService;

  const GetInvoiceUsecase({required this._payService});

  Future<InvoiceStatusSnapshot> execute(InvoiceId invoiceId) async {
    return _payService.getInvoiceStatus(invoiceId);
  }
}
