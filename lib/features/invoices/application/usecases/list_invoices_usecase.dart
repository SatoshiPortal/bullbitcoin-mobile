import 'package:bb_mobile/features/invoices/application/commands/invoice_commands.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_identity_port.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_pay_service_port.dart';
import 'package:bb_mobile/features/invoices/application/results/invoice_results.dart';

/// Lists the merchant's invoices (signed `invoice-list`). Resolves the signer
/// then delegates; the result carries the mapped domain [Invoice]s + paging.
class ListInvoicesUsecase {
  final InvoicesIdentityPort _identity;
  final InvoicesPayServicePort _payService;

  const ListInvoicesUsecase({
    required this._identity,
    required this._payService,
  });

  Future<ListInvoicesResult> execute(ListInvoicesCommand command) async {
    final signer = await _identity.getSigningHandle();
    return _payService.listInvoices(signer: signer, command: command);
  }
}
