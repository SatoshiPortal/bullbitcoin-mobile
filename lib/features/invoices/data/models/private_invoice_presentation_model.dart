import 'package:bb_mobile/features/invoices/domain/entities/private_invoice_presentation.dart';

class PrivateInvoicePresentationModel {
  final Map<String, Object> value;

  const PrivateInvoicePresentationModel._(this.value);

  factory PrivateInvoicePresentationModel.fromEntity(
    PrivateInvoicePresentation entity,
  ) {
    Map<String, Object>? contact(PrivateInvoiceContact? value) {
      if (value == null) return null;
      return {
        if (value.name != null) 'name': value.name!,
        if (value.corporateName != null) 'corporate_name': value.corporateName!,
        if (value.address != null) 'address': value.address!,
        if (value.email != null) 'email': value.email!,
        if (value.phone != null) 'phone': value.phone!,
      };
    }

    Map<String, Object>? invoice(PrivateInvoiceDetails? value) {
      if (value == null) return null;
      return {
        if (value.description != null) 'description': value.description!,
        if (value.number != null) 'number': value.number!,
        if (value.purchaseOrderReference != null)
          'purchase_order_reference': value.purchaseOrderReference!,
        if (value.invoiceDate != null) 'invoice_date': value.invoiceDate!,
        if (value.paymentDeadline != null)
          'payment_deadline': value.paymentDeadline!,
      };
    }

    return PrivateInvoicePresentationModel._({
      'schema': 'bullnym-private-invoice',
      'version': 1,
      'payer': ?contact(entity.payer),
      'invoice': ?invoice(entity.invoice),
      'payee': ?contact(entity.payee),
    });
  }
}
