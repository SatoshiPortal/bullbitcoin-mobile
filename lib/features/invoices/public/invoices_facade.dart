import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart'
    show BullnymFacade, BullnymSupportedCurrencies;
import 'package:bb_mobile/features/invoices/application/commands/invoice_commands.dart';
import 'package:bb_mobile/features/invoices/application/results/invoice_results.dart';
import 'package:bb_mobile/features/invoices/application/usecases/cancel_invoice_usecase.dart';
import 'package:bb_mobile/features/invoices/application/usecases/create_invoice_usecase.dart';
import 'package:bb_mobile/features/invoices/application/usecases/get_invoice_usecase.dart';
import 'package:bb_mobile/features/invoices/application/usecases/list_invoices_usecase.dart';
import 'package:bb_mobile/features/invoices/application/usecases/list_invoice_fallback_supervision_usecase.dart';
import 'package:bb_mobile/features/invoices/domain/bullnym_failure_mapping.dart';
import 'package:bb_mobile/features/invoices/domain/entities/invoice_fallback_supervision.dart';
import 'package:bb_mobile/features/invoices/domain/usecases/get_private_invoice_link_usecase.dart';
import 'package:bb_mobile/features/invoices/domain/entities/invoice_status_snapshot.dart';
import 'package:bb_mobile/features/invoices/domain/invoices_failure.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/private_invoice_link.dart';
import 'package:meta/meta.dart';

export 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart'
    show BullnymSupportedCurrencies, BullnymSupportedCurrency;
export 'package:bb_mobile/features/invoices/application/commands/invoice_commands.dart';
export 'package:bb_mobile/features/invoices/application/results/invoice_results.dart';
export 'package:bb_mobile/features/invoices/domain/entities/invoice.dart';
export 'package:bb_mobile/features/invoices/domain/entities/invoice_fallback_supervision.dart';
export 'package:bb_mobile/features/invoices/domain/entities/invoice_status_snapshot.dart';
export 'package:bb_mobile/features/invoices/domain/invoices_failure.dart';
export 'package:bb_mobile/features/invoices/domain/primitives/invoice_status.dart';
export 'package:bb_mobile/features/invoices/domain/primitives/payment_method.dart';
export 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';
export 'package:bb_mobile/features/invoices/domain/value_objects/private_invoice_link.dart';

/// The public entry to the invoices feature. Thin delegations to the usecases;
/// `supportedCurrencies` reuses the shared bullnym currency plumbing.
class InvoicesFacade {
  final CreateInvoiceUsecase _create;
  final CancelInvoiceUsecase _cancel;
  final ListInvoicesUsecase _list;
  final ListInvoiceFallbackSupervisionUsecase _listFallbackSupervision;
  final GetInvoiceUsecase _getStatus;
  final GetPrivateInvoiceLinkUsecase _getPrivateLink;
  final BullnymFacade _bullnym;

  const InvoicesFacade({
    required this._create,
    required this._cancel,
    required this._list,
    required this._listFallbackSupervision,
    required this._getStatus,
    required this._getPrivateLink,
    required this._bullnym,
  });

  @useResult
  Future<Result<CreateInvoiceResult, InvoicesFailure>> create(
    CreateInvoiceCommand command,
  ) => _create.execute(command);

  @useResult
  Future<Result<CreateInvoiceResult?, InvoicesFailure>> resumeCreate() =>
      _create.resumePending();

  @useResult
  Future<Result<CancelInvoiceResult, InvoicesFailure>> cancel(
    CancelInvoiceCommand command,
  ) => _cancel.execute(command);

  @useResult
  Future<Result<ListInvoicesResult, InvoicesFailure>> list(
    ListInvoicesCommand command,
  ) => _list.execute(command);

  @useResult
  Future<Result<InvoiceFallbackOverview, InvoicesFailure>>
  fallbackSupervision() => _listFallbackSupervision.execute();

  @useResult
  Future<Result<InvoiceStatusSnapshot, InvoicesFailure>> status(
    InvoiceId invoiceId,
  ) => _getStatus.execute(invoiceId);

  Future<PrivateInvoiceLink?> privateLink(InvoiceId invoiceId) =>
      _getPrivateLink.execute(invoiceId);

  @useResult
  Future<Result<BullnymSupportedCurrencies, InvoicesFailure>>
  supportedCurrencies() async {
    final result = await _bullnym.getSupportedCurrencies();
    return result.mapErr(mapBullnymFailureToInvoices);
  }

  @override
  String toString() => 'InvoicesFacade';
}
