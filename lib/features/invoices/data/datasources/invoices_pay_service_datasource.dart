import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/invoices/application/commands/invoice_commands.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_pay_service_port.dart';
import 'package:bb_mobile/features/invoices/application/results/invoice_results.dart';
import 'package:bb_mobile/features/invoices/domain/entities/invoice.dart';
import 'package:bb_mobile/features/invoices/domain/entities/invoice_status_snapshot.dart';
import 'package:bb_mobile/features/invoices/domain/invoices_failure.dart';
import 'package:bb_mobile/features/invoices/domain/primitives/invoice_status.dart';
import 'package:bb_mobile/features/invoices/domain/primitives/payment_method.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_url.dart';

/// Implements [InvoicesPayServicePort] over the shared `bullnym` client.
/// It maps commands → wire DTOs and DTOs → domain entities, and translates
/// every recoverable exception into an [InvoicesFailure] so no wire type or
/// server diagnostic escapes upward.
class InvoicesPayServiceDatasource implements InvoicesPayServicePort {
  final BullnymFacade _bullnym;

  const InvoicesPayServiceDatasource({required this._bullnym});

  @override
  Future<Result<CreateInvoiceResult, InvoicesFailure>> createInvoice({
    required BullnymAuthSigner signer,
    required CreateInvoiceCommand command,
    String? bitcoinAddress,
    String? liquidAddress,
    String? liquidBlindingKeyHex,
  }) async {
    try {
      final fields = BullnymCreateInvoiceFields(
        amountSat: command.amountSat,
        fiatAmountMinor: command.fiatAmountMinor,
        fiatCurrency: command.fiatCurrency,
        publicDescription: command.publicDescription,
        recipientName: command.recipientName,
        invoiceNumber: command.invoiceNumber,
        acceptBtc: command.acceptBtc,
        acceptLn: command.acceptLn,
        acceptLiquid: command.acceptLiquid,
        bitcoinAddress: bitcoinAddress,
        liquidAddress: liquidAddress,
        liquidBlindingKeyHex: liquidBlindingKeyHex,
        expiresAtUnix: _toUnix(command.expiresAt),
      );
      final response = await _bullnym.createInvoice(
        signer: signer,
        nym: command.linkToPageNym,
        fields: fields,
      );
      return Ok(
        CreateInvoiceResult(
          invoiceId: _invoiceId(response.invoiceId),
          shareUrl: _invoiceUrl(response.shareUrl),
        ),
      );
    } on BullnymException catch (e) {
      return Err(_mapBullnymFailure(e));
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
      final response = await _bullnym.cancelInvoice(
        signer: signer,
        nym: command.nymOwner,
        invoiceId: command.invoiceId.value,
      );
      final parsedStatus = _invoiceStatus(response.status, operation: 'cancel');
      return Ok(
        CancelInvoiceResult(
          invoiceId: _invoiceId(response.invoiceId),
          finalStatus: parsedStatus,
        ),
      );
    } on BullnymException catch (e) {
      return Err(_mapBullnymFailure(e));
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
      final response = await _bullnym.listInvoices(
        signer: signer,
        page: command.page,
        pageSize: command.pageSize,
        status: command.status?.wire,
      );
      return Ok(
        ListInvoicesResult(
          invoices: response.invoices.map(_toInvoice).toList(),
          page: response.page,
          pageSize: response.pageSize,
          hasMore: response.hasMore,
        ),
      );
    } on BullnymException catch (e) {
      return Err(_mapBullnymFailure(e));
    } on ArgumentError {
      return const Err(InvoicesFailure.invalidServerResponse());
    } on Exception catch (error, stack) {
      return _unexpectedFailure('list', error, stack);
    }
  }

  @override
  Future<Result<InvoiceStatusSnapshot, InvoicesFailure>> getInvoiceStatus(
    InvoiceId invoiceId,
  ) async {
    try {
      final status = await _bullnym.getInvoiceStatus(
        invoiceId: invoiceId.value,
      );
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
    } on BullnymException catch (e) {
      return Err(_mapBullnymFailure(e));
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
      amountSat: item.amountSat,
      remainingAmountSat: item.remainingAmountSat,
      fiatAmountMinor: item.fiatAmountMinor,
      fiatCurrency: item.fiatCurrency,
      publicDescription: item.publicDescription,
      recipientName: item.recipientName,
      invoiceNumber: item.invoiceNumber,
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

  int _toUnix(DateTime dateTime) =>
      dateTime.toUtc().millisecondsSinceEpoch ~/ 1000;

  DateTime _fromUnix(int unix) =>
      DateTime.fromMillisecondsSinceEpoch(unix * 1000, isUtc: true);

  InvoiceId _invoiceId(String raw) => InvoiceId(raw);

  InvoiceUrl _invoiceUrl(String raw) => InvoiceUrl(raw);

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

  InvoicesFailure _mapBullnymFailure(BullnymException error) {
    return switch (error.kind) {
      BullnymErrorKind.invalidInput => InvoicesFailure.invalidInput(
        code: error.code,
      ),
      BullnymErrorKind.network => const InvoicesFailure.network(),
      BullnymErrorKind.timeout => const InvoicesFailure.timeout(),
      BullnymErrorKind.serverRejectedRequest => switch (error.code) {
        'InvoiceNotFound' => const InvoicesFailure.notFound(),
        'InvalidAmount' => InvoicesFailure.invalidInput(code: error.code),
        'AuthError' => const InvoicesFailure.authError(),
        'BitcoinAddressAlreadyUsed' =>
          const InvoicesFailure.reusedBitcoinAddress(),
        'LiquidAddressAlreadyUsed' =>
          const InvoicesFailure.reusedLiquidAddress(),
        'RateLimitedSender' ||
        'RateLimitedRecipient' ||
        'RateLimitedNetwork' => const InvoicesFailure.rateLimited(),
        _ => InvoicesFailure.server(retryable: error.retryable),
      },
      BullnymErrorKind.unexpectedHttpStatus => const InvoicesFailure.server(
        retryable: true,
      ),
      BullnymErrorKind.emptyResponse ||
      BullnymErrorKind.invalidServerResponse =>
        const InvoicesFailure.invalidServerResponse(),
      BullnymErrorKind.signingFailed => const InvoicesFailure.signingFailed(),
    };
  }
}
