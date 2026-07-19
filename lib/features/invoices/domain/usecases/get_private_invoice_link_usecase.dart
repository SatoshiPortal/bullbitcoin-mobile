import 'package:bb_mobile/features/invoices/domain/repositories/private_invoice_link_repository.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/private_invoice_link.dart';

class GetPrivateInvoiceLinkUsecase {
  final PrivateInvoiceLinkRepository _repository;

  const GetPrivateInvoiceLinkUsecase(this._repository);

  Future<PrivateInvoiceLink?> execute(InvoiceId invoiceId) =>
      _repository.getRetainedLink(invoiceId);
}
