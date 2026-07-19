import 'package:bb_mobile/features/invoices/domain/entities/invoice.dart';
import 'package:bb_mobile/features/invoices/domain/primitives/invoice_status.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/private_invoice_link.dart';

/// The result of creating an invoice and retaining its complete private link.
class CreateInvoiceResult {
  final InvoiceId invoiceId;
  final PrivateInvoiceLink privateLink;

  const CreateInvoiceResult({
    required this.invoiceId,
    required this.privateLink,
  });
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
