import 'package:bb_mobile/features/invoices/domain/entities/encrypted_private_invoice.dart';
import 'package:bb_mobile/features/invoices/domain/entities/private_invoice_presentation.dart';

abstract interface class PrivateInvoiceCipher {
  String newClientRequestId();

  Future<EncryptedPrivateInvoice> encrypt(
    PrivateInvoicePresentation presentation,
  );
}
