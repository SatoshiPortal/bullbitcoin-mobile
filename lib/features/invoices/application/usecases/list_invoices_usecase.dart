import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/invoices/application/commands/invoice_commands.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_identity_port.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_pay_service_port.dart';
import 'package:bb_mobile/features/invoices/application/results/invoice_results.dart';
import 'package:bb_mobile/features/invoices/domain/invoices_failure.dart';
import 'package:meta/meta.dart';

/// Lists the merchant's invoices (signed `invoice-list`). Resolves the signer
/// then delegates; the result carries the mapped domain [Invoice]s + paging.
class ListInvoicesUsecase {
  final InvoicesIdentityPort _identity;
  final InvoicesPayServicePort _payService;

  const ListInvoicesUsecase({
    required this._identity,
    required this._payService,
  });

  @useResult
  Future<Result<ListInvoicesResult, InvoicesFailure>> execute(
    ListInvoicesCommand command,
  ) async {
    return switch (await _identity.getSigningHandle()) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => _payService.listInvoices(
        signer: value,
        command: command,
      ),
    };
  }
}
