import 'package:bb_mobile/features/invoices/domain/entities/prepared_private_invoice_create.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/private_invoice_link.dart';

abstract interface class PrivateInvoiceLinkRepository {
  Future<PreparedPrivateInvoiceCreate?> getPending();

  Future<void> savePending(PreparedPrivateInvoiceCreate operation);

  Future<void> deletePending(String clientRequestId);

  Future<PrivateInvoiceLink?> getRetainedLink(InvoiceId invoiceId);

  Future<void> retainLink(PrivateInvoiceLink link);
}
