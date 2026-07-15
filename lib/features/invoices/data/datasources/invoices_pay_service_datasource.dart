import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_config.dart';
import 'package:bb_mobile/features/invoices/application/commands/invoice_commands.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_pay_service_port.dart';
import 'package:bb_mobile/features/invoices/application/results/invoice_results.dart';
import 'package:bb_mobile/features/invoices/domain/bullnym_failure_mapping.dart';
import 'package:bb_mobile/features/invoices/domain/entities/invoice.dart';
import 'package:bb_mobile/features/invoices/domain/entities/invoice_fallback_supervision.dart';
import 'package:bb_mobile/features/invoices/domain/entities/invoice_status_snapshot.dart';
import 'package:bb_mobile/features/invoices/domain/entities/prepared_private_invoice_create.dart';
import 'package:bb_mobile/features/invoices/domain/invoices_failure.dart';
import 'package:bb_mobile/features/invoices/domain/primitives/invoice_status.dart';
import 'package:bb_mobile/features/invoices/domain/primitives/payment_method.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/private_invoice_link.dart';

/// Implements [InvoicesPayServicePort] over the shared `bullnym` client.
/// It maps commands → wire DTOs and DTOs → domain entities, and translates
/// every recoverable Bullnym failure into an [InvoicesFailure] so no wire type or
/// server diagnostic escapes upward.
class InvoicesPayServiceDatasource implements InvoicesPayServicePort {
  final BullnymFacade _bullnym;
  final Uri _expectedOrigin;

  InvoicesPayServiceDatasource({
    required BullnymFacade bullnym,
    Uri? expectedOrigin,
  }) : this._(bullnym, expectedOrigin ?? Uri.parse(bullnymDefaultBaseUrl));

  InvoicesPayServiceDatasource._(this._bullnym, this._expectedOrigin);

  @override
  Future<Result<CreateInvoiceResult, InvoicesFailure>> createInvoice({
    required BullnymAuthSigner signer,
    required PreparedPrivateInvoiceCreate operation,
  }) async {
    try {
      final fields = BullnymCreateInvoiceFields(
        amountSat: operation.amountSat,
        fiatAmountMinor: operation.fiatAmountMinor,
        fiatCurrency: operation.fiatCurrency,
        clientRequestId: operation.encrypted.clientRequestId,
        presentationEnvelope: operation.encrypted.presentationEnvelope,
        acceptBtc: operation.acceptBtc,
        acceptLn: operation.acceptLn,
        acceptLiquid: operation.acceptLiquid,
        bitcoinAddress: operation.bitcoinAddress,
        liquidAddress: operation.liquidAddress,
        liquidBlindingKeyHex: operation.liquidBlindingKeyHex,
        expiresAtUnix: operation.expiresAtUnix,
      );
      final responseResult = await _bullnym.createInvoice(
        signer: signer,
        nym: operation.linkToPageNym,
        fields: fields,
      );
      final BullnymCreateInvoiceResponse response;
      switch (responseResult) {
        case Ok(:final value):
          response = value;
        case Err(:final failure):
          return Err(mapBullnymFailureToInvoices(failure));
      }
      final invoiceId = _invoiceId(response.invoiceId);
      return Ok(
        CreateInvoiceResult(
          invoiceId: invoiceId,
          privateLink: PrivateInvoiceLink.fromServer(
            invoiceUrl: response.invoiceUrl,
            expectedInvoiceId: invoiceId,
            viewingKey: operation.encrypted.viewingKey,
            expectedOrigin: _expectedOrigin,
          ),
        ),
      );
    } on ArgumentError {
      return const Err(InvoicesFailure.invalidServerResponse());
    } on Exception catch (error, stack) {
      return _unexpectedFailure('create', error, stack);
    }
  }

  @override
  Future<Result<CancelInvoiceResult, InvoicesFailure>> cancelInvoice({
    required BullnymAuthSigner signer,
    required CancelInvoiceCommand command,
  }) async {
    try {
      final responseResult = await _bullnym.cancelInvoice(
        signer: signer,
        nym: command.nymOwner,
        invoiceId: command.invoiceId.value,
      );
      final BullnymCancelInvoiceResponse response;
      switch (responseResult) {
        case Ok(:final value):
          response = value;
        case Err(:final failure):
          return Err(mapBullnymFailureToInvoices(failure));
      }
      final parsedStatus = _invoiceStatus(response.status, operation: 'cancel');
      return Ok(
        CancelInvoiceResult(
          invoiceId: _invoiceId(response.invoiceId),
          finalStatus: parsedStatus,
        ),
      );
    } on ArgumentError {
      return const Err(InvoicesFailure.invalidServerResponse());
    } on Exception catch (error, stack) {
      return _unexpectedFailure('cancel', error, stack);
    }
  }

  @override
  Future<Result<ListInvoicesResult, InvoicesFailure>> listInvoices({
    required BullnymAuthSigner signer,
    required ListInvoicesCommand command,
  }) async {
    try {
      final responseResult = await _bullnym.listInvoices(
        signer: signer,
        page: command.page,
        pageSize: command.pageSize,
        status: command.status?.wire,
      );
      final BullnymListInvoicesResponse response;
      switch (responseResult) {
        case Ok(:final value):
          response = value;
        case Err(:final failure):
          return Err(mapBullnymFailureToInvoices(failure));
      }
      return Ok(
        ListInvoicesResult(
          invoices: response.invoices.map(_toInvoice).toList(),
          page: response.page,
          pageSize: response.pageSize,
          hasMore: response.hasMore,
        ),
      );
    } on ArgumentError {
      return const Err(InvoicesFailure.invalidServerResponse());
    } on Exception catch (error, stack) {
      return _unexpectedFailure('list', error, stack);
    }
  }

  @override
  Future<Result<InvoiceFallbackOverview, InvoicesFailure>>
  listFallbackSupervision({required BullnymAuthSigner signer}) async {
    try {
      final result = await _bullnym.listFallbackSupervision(signer: signer);
      switch (result) {
        case Ok(:final value):
          return Ok(
            InvoiceFallbackOverview(
              items: value.items.map(_toFallbackSupervision).toList(),
              hasMore: value.hasMore,
            ),
          );
        case Err(:final failure):
          if (failure.statusCode == 404 || failure.statusCode == 405) {
            return const Ok(InvoiceFallbackOverview(items: [], hasMore: false));
          }
          return Err(mapBullnymFailureToInvoices(failure));
      }
    } on ArgumentError {
      return const Err(InvoicesFailure.invalidServerResponse());
    } on Exception catch (error, stack) {
      return _unexpectedFailure('fallback supervision', error, stack);
    }
  }

  @override
  Future<Result<InvoiceStatusSnapshot, InvoicesFailure>> getInvoiceStatus(
    InvoiceId invoiceId,
  ) async {
    try {
      final statusResult = await _bullnym.getInvoiceStatus(
        invoiceId: invoiceId.value,
      );
      final BullnymInvoiceStatus status;
      switch (statusResult) {
        case Ok(:final value):
          status = value;
        case Err(:final failure):
          return Err(mapBullnymFailureToInvoices(failure));
      }
      final parsedStatus = _invoiceStatus(status.status, operation: 'status');
      return Ok(
        InvoiceStatusSnapshot(
          status: parsedStatus,
          pricingMode: status.pricingMode,
          settlementStatus: status.settlementStatus,
          amountSat: status.amountSat,
          fiatAmountMinor: status.fiatAmountMinor,
          fiatCurrency: status.fiatCurrency,
          remainingAmountSat: status.remainingAmountSat,
          paymentToleranceSat: status.paymentToleranceSat,
          rateMinorPerBtc: status.rateMinorPerBtc,
          rateLocksUntil: _fromUnix(status.rateLocksUntilUnix),
          expiresAt: _fromUnix(status.expiresAtUnix),
          paidVia: PaymentMethod.fromWire(status.paidVia),
          paidAt: status.paidAtUnix == null
              ? null
              : _fromUnix(status.paidAtUnix!),
          paidAmountSat: status.paidAmountSat,
          lightningPr: status.lightningPr,
          liquidAddress: status.liquidAddress,
          bitcoinAddress: status.bitcoinAddress,
          bitcoinChainAddress: status.bitcoinChainAddress,
          bitcoinChainBip21: status.bitcoinChainBip21,
          acceptBtc: status.acceptBtc,
          acceptLn: status.acceptLn,
          acceptLiquid: status.acceptLiquid,
        ),
      );
    } on ArgumentError {
      return const Err(InvoicesFailure.invalidServerResponse());
    } on Exception catch (error, stack) {
      return _unexpectedFailure('status', error, stack);
    }
  }

  Invoice _toInvoice(BullnymInvoiceListItem item) {
    return Invoice(
      id: _invoiceId(item.id),
      nymOwner: item.nymOwner,
      status: _invoiceStatus(item.status, operation: 'list'),
      presentationStatus: item.presentationStatus,
      amountSat: item.amountSat,
      remainingAmountSat: item.remainingAmountSat,
      fiatAmountMinor: item.fiatAmountMinor,
      fiatCurrency: item.fiatCurrency,
      memo: item.memo,
      acceptBtc: item.acceptBtc,
      acceptLn: item.acceptLn,
      acceptLiquid: item.acceptLiquid,
      bitcoinAddress: item.bitcoinAddress,
      liquidAddress: item.liquidAddress,
      createdAt: _fromUnix(item.createdAtUnix),
      expiresAt: _fromUnix(item.expiresAtUnix),
      paidVia: PaymentMethod.fromWire(item.paidVia),
      paidAt: item.paidAtUnix == null ? null : _fromUnix(item.paidAtUnix!),
      paidAmountSat: item.paidAmountSat,
    );
  }

  InvoiceFallbackSupervision _toFallbackSupervision(
    BullnymFallbackSupervisionItem item,
  ) {
    return InvoiceFallbackSupervision(
      invoiceId: _invoiceId(item.invoiceId),
      nym: item.nym,
      state: invoiceFallbackStateFromWire(item.recoveryStatus),
      payerAmountSat: item.userLockAmountSat,
      invoiceSwapAmountSat: item.serverLockAmountSat,
      lockupAddress: item.lockupAddress,
      fallbackAddress: item.refundAddress,
      transactionId: item.refundTxid,
      createdAt: _fromUnix(item.swapCreatedAtUnix),
      updatedAt: _fromUnix(item.swapUpdatedAtUnix),
    );
  }

  DateTime _fromUnix(int unix) =>
      DateTime.fromMillisecondsSinceEpoch(unix * 1000, isUtc: true);

  InvoiceId _invoiceId(String raw) => InvoiceId(raw);

  InvoiceStatus _invoiceStatus(String raw, {required String operation}) {
    final status = InvoiceStatus.fromWire(raw);
    if (status == InvoiceStatus.unsupported) {
      log.warning(
        'Invoice $operation response contained unsupported status',
        error: raw,
      );
    }
    return status;
  }

  Result<T, InvoicesFailure> _unexpectedFailure<T>(
    String operation,
    Exception error,
    StackTrace stack,
  ) {
    log.warning(
      'Invoice $operation request failed unexpectedly',
      error: error,
      trace: stack,
    );
    return const Err(InvoicesFailure.unexpected());
  }
}
