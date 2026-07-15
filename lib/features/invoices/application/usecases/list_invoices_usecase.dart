import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart'
    show BullnymAuthSigner;
import 'package:bb_mobile/features/invoices/application/commands/invoice_commands.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_identity_port.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_pay_service_port.dart';
import 'package:bb_mobile/features/invoices/application/results/invoice_results.dart';
import 'package:bb_mobile/features/invoices/domain/entities/invoice_fallback_supervision.dart';
import 'package:bb_mobile/features/invoices/domain/invoices_failure.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';
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
    final signerResult = await _identity.getSigningHandle();
    return switch (signerResult) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => _listWithSupervision(value, command),
    };
  }

  Future<Result<ListInvoicesResult, InvoicesFailure>> _listWithSupervision(
    BullnymAuthSigner signer,
    ListInvoicesCommand command,
  ) async {
    final listResult = await _payService.listInvoices(
      signer: signer,
      command: command,
    );
    final ListInvoicesResult list;
    switch (listResult) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        list = value;
    }

    final supervisionResult = await _payService.listFallbackSupervision(
      signer: signer,
    );
    switch (supervisionResult) {
      case Err():
        return Ok(
          ListInvoicesResult(
            invoices: list.invoices,
            page: list.page,
            pageSize: list.pageSize,
            hasMore: list.hasMore,
            fallbackSupervisionUnavailable: true,
          ),
        );
      case Ok(:final value):
        final byInvoice = <InvoiceId, List<InvoiceFallbackSupervision>>{};
        for (final item in value.items) {
          byInvoice.putIfAbsent(item.invoiceId, () => []).add(item);
        }
        return Ok(
          ListInvoicesResult(
            invoices: [
              for (final invoice in list.invoices)
                invoice.withFallbackSupervisions(
                  byInvoice[invoice.id] ?? const [],
                ),
            ],
            page: list.page,
            pageSize: list.pageSize,
            hasMore: list.hasMore,
            fallbackSupervisionOverflow: value.hasMore,
          ),
        );
    }
  }
}
