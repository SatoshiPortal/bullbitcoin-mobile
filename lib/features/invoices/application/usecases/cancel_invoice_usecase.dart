import 'package:bb_mobile/features/invoices/application/commands/invoice_commands.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_identity_port.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_pay_service_port.dart';
import 'package:bb_mobile/features/invoices/application/results/invoice_results.dart';

/// Cancels an invoice: resolve the signer, sign the `invoice-cancel`, and
/// return the server's final status. Ownership is enforced server-side (a
/// non-owner surfaces as notFound); no local labels are deleted (wallet
/// history is preserved).
class CancelInvoiceUsecase {
  final InvoicesIdentityPort _identity;
  final InvoicesPayServicePort _payService;

  const CancelInvoiceUsecase({
    required this._identity,
    required this._payService,
  });

  Future<CancelInvoiceResult> execute(CancelInvoiceCommand command) async {
    final signer = await _identity.getSigningHandle();
    return _payService.cancelInvoice(signer: signer, command: command);
  }
}
