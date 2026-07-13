import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/invoices/application/commands/invoice_commands.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_identity_port.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_pay_service_port.dart';
import 'package:bb_mobile/features/invoices/application/results/invoice_results.dart';
import 'package:bb_mobile/features/invoices/domain/invoices_failure.dart';
import 'package:meta/meta.dart';

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

  @useResult
  Future<Result<CancelInvoiceResult, InvoicesFailure>> execute(
    CancelInvoiceCommand command,
  ) async {
    return switch (await _identity.getSigningHandle()) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => _payService.cancelInvoice(
        signer: value,
        command: command,
      ),
    };
  }
}
