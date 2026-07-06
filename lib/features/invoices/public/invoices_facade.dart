import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart'
    show BullnymFacade, BullnymSupportedCurrencies;
import 'package:bb_mobile/features/invoices/application/commands/invoice_commands.dart';
import 'package:bb_mobile/features/invoices/application/results/invoice_results.dart';
import 'package:bb_mobile/features/invoices/application/usecases/cancel_invoice_usecase.dart';
import 'package:bb_mobile/features/invoices/application/usecases/create_invoice_usecase.dart';
import 'package:bb_mobile/features/invoices/application/usecases/get_invoice_usecase.dart';
import 'package:bb_mobile/features/invoices/application/usecases/list_invoices_usecase.dart';
import 'package:bb_mobile/features/invoices/domain/entities/invoice_status_snapshot.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';

export 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart'
    show BullnymSupportedCurrencies, BullnymSupportedCurrency;
export 'package:bb_mobile/features/invoices/application/commands/invoice_commands.dart';
export 'package:bb_mobile/features/invoices/application/results/invoice_results.dart';
export 'package:bb_mobile/features/invoices/domain/entities/invoice.dart';
export 'package:bb_mobile/features/invoices/domain/entities/invoice_status_snapshot.dart';
export 'package:bb_mobile/features/invoices/domain/invoices_error.dart';
export 'package:bb_mobile/features/invoices/domain/primitives/invoice_status.dart';
export 'package:bb_mobile/features/invoices/domain/primitives/payment_method.dart';
export 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';
export 'package:bb_mobile/features/invoices/domain/value_objects/invoice_url.dart';

/// The public entry to the invoices feature. Thin delegations to the usecases;
/// `supportedCurrencies` reuses the shared bullnym currency plumbing.
class InvoicesFacade {
  final CreateInvoiceUsecase _create;
  final CancelInvoiceUsecase _cancel;
  final ListInvoicesUsecase _list;
  final GetInvoiceUsecase _getStatus;
  final BullnymFacade _bullnym;

  const InvoicesFacade({
    required this._create,
    required this._cancel,
    required this._list,
    required this._getStatus,
    required this._bullnym,
  });

  Future<CreateInvoiceResult> create(CreateInvoiceCommand command) =>
      _create.execute(command);

  Future<CancelInvoiceResult> cancel(CancelInvoiceCommand command) =>
      _cancel.execute(command);

  Future<ListInvoicesResult> list(ListInvoicesCommand command) =>
      _list.execute(command);

  Future<InvoiceStatusSnapshot> status(InvoiceId invoiceId) =>
      _getStatus.execute(invoiceId);

  Future<BullnymSupportedCurrencies> supportedCurrencies() =>
      _bullnym.getSupportedCurrencies();

  @override
  String toString() => 'InvoicesFacade';
}
