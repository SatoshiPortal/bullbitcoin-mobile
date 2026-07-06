import 'package:bb_mobile/features/invoices/domain/entities/invoice.dart';
import 'package:bb_mobile/features/invoices/domain/primitives/invoice_status.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_url.dart';

/// The result of creating an invoice: the id and the validated (HTTPS) public
/// share URL.
class CreateInvoiceResult {
  final InvoiceId invoiceId;
  final InvoiceUrl shareUrl;

  const CreateInvoiceResult({required this.invoiceId, required this.shareUrl});
}

/// The result of cancelling an invoice: the id and the final status the server
/// settled on (cancelled, or a pre-existing terminal status on a race).
class CancelInvoiceResult {
  final InvoiceId invoiceId;
  final InvoiceStatus finalStatus;

  const CancelInvoiceResult({
    required this.invoiceId,
    required this.finalStatus,
  });
}

/// A page of the merchant's invoices.
class ListInvoicesResult {
  final List<Invoice> invoices;
  final int page;
  final int pageSize;
  final bool hasMore;

  const ListInvoicesResult({
    required this.invoices,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });
}
