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
import 'package:bb_mobile/features/invoices/domain/entities/invoice_payment_event.dart';
import 'package:bb_mobile/features/invoices/domain/entities/invoice_payer_amount.dart';
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
      return Ok(
        CancelInvoiceResult(
          invoiceId: _invoiceId(response.invoiceId),
          finalStatus: _invoiceStatus(response.status, operation: 'cancel'),
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
      final invoiceStatus = _invoiceStatus(status.status, operation: 'status');
      final hasPaymentEvidence =
          status.bitcoinDirectObservations.isNotEmpty ||
          status.paidVia != null ||
          status.paidAtUnix != null ||
          status.paidAmountSat != null ||
          _statusCarriesPaymentEvidence(invoiceStatus);
      final mappedSettlementState = invoiceSettlementStateFromWire(
        settlementStatus: status.settlementStatus,
        presentationStatus: status.presentationStatus,
        hasPaymentEvidence: hasPaymentEvidence,
      );
      final settlementState =
          mappedSettlementState != InvoiceSettlementState.settled &&
              status.bitcoinDirectObservations.any(
                (observation) =>
                    invoicePaymentProblemFromWire(observation.state) != null,
              )
          ? InvoiceSettlementState.problem
          : mappedSettlementState;
      final expiresAt = _fromUnix(status.expiresAtUnix);
      final paymentEvents = [
        for (final observation in status.bitcoinDirectObservations)
          _toPaymentEvent(
            observation,
            invoiceStatus: invoiceStatus,
            invoiceSettlement: settlementState,
            invoiceExpiresAt: expiresAt,
            presentationMarksLate: invoicePresentationMarksLate(
              status.presentationStatus,
            ),
          ),
      ];
      if (paymentEvents.isEmpty &&
          status.paidVia != null &&
          status.paidAtUnix != null &&
          status.paidAmountSat != null) {
        final aggregate = _toAggregatePaymentEvent(
          status,
          invoiceStatus: invoiceStatus,
          invoiceSettlement: settlementState,
          invoiceExpiresAt: expiresAt,
        );
        if (aggregate != null) paymentEvents.add(aggregate);
      }
      return Ok(
        InvoiceStatusSnapshot(
          status: invoiceStatus,
          settlementState: settlementState,
          pricingMode: status.pricingMode,
          settlementStatus: status.settlementStatus,
          amountSat: status.amountSat,
          fiatAmountMinor: status.fiatAmountMinor,
          fiatCurrency: status.fiatCurrency,
          remainingAmountSat: status.remainingAmountSat,
          paymentToleranceSat: status.paymentToleranceSat,
          rateMinorPerBtc: status.rateMinorPerBtc,
          rateLocksUntil: _fromUnix(status.rateLocksUntilUnix),
          expiresAt: expiresAt,
          paidVia: PaymentMethod.fromWire(status.paidVia),
          paidAt: status.paidAtUnix == null
              ? null
              : _fromUnix(status.paidAtUnix!),
          paidAmountSat: status.paidAmountSat,
          lightningPr: status.lightningPr,
          lightningPayerAmount: _toPayerAmount(
            PaymentMethod.lightning,
            payerAmountSat: status.lightningAmountSat,
            merchantTargetAmountSat: status.remainingAmountSat,
          ),
          liquidAddress: status.liquidAddress,
          liquidPayerAmount: _toPayerAmount(
            PaymentMethod.liquid,
            payerAmountSat: status.liquidAmountSat,
            merchantTargetAmountSat: status.remainingAmountSat,
          ),
          bitcoinAddress: status.bitcoinAddress,
          bitcoinChainAddress: status.bitcoinChainAddress,
          bitcoinChainBip21: status.bitcoinChainBip21,
          bitcoinChainPayerAmount: _toPayerAmount(
            PaymentMethod.btc,
            payerAmountSat: status.bitcoinChainAmountSat,
            merchantTargetAmountSat: status.remainingAmountSat,
          ),
          acceptBtc: status.acceptBtc,
          acceptLn: status.acceptLn,
          acceptLiquid: status.acceptLiquid,
          paymentEvents: paymentEvents,
          presentationMarksLatePayment: invoicePresentationMarksLate(
            status.presentationStatus,
          ),
        ),
      );
    } on ArgumentError {
      return const Err(InvoicesFailure.invalidServerResponse());
    } on Exception catch (error, stack) {
      return _unexpectedFailure('status', error, stack);
    }
  }

  Invoice _toInvoice(BullnymInvoiceListItem item) {
    final status = _invoiceStatus(item.status, operation: 'list');
    final hasPaymentEvidence =
        item.paidVia != null ||
        item.paidAtUnix != null ||
        item.paidAmountSat != null ||
        _statusCarriesPaymentEvidence(status);
    return Invoice(
      id: _invoiceId(item.id),
      nymOwner: item.nymOwner,
      status: status,
      presentationStatus: item.presentationStatus,
      settlementState: invoiceSettlementStateFromWire(
        settlementStatus: item.settlementStatus,
        presentationStatus: item.presentationStatus,
        hasPaymentEvidence: hasPaymentEvidence,
      ),
      presentationMarksLatePayment: invoicePresentationMarksLate(
        item.presentationStatus,
      ),
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

  InvoicePaymentEvent _toPaymentEvent(
    BullnymBitcoinDirectObservation observation, {
    required InvoiceStatus invoiceStatus,
    required InvoiceSettlementState invoiceSettlement,
    required DateTime invoiceExpiresAt,
    required bool presentationMarksLate,
  }) {
    final firstSeenAt = _fromUnix(observation.firstSeenAtUnix);
    final eventState = invoicePaymentEventStateFromWire(
      state: observation.state,
      confirmations: observation.confirmations,
      invoiceSettlement: invoiceSettlement,
    );
    return InvoicePaymentEvent(
      rail: PaymentMethod.fromWire(observation.rail) ?? PaymentMethod.btc,
      amountSat: observation.amountSat,
      firstSeenAt: firstSeenAt,
      lastSeenAt: _fromUnix(observation.lastSeenAtUnix),
      state: eventState,
      confirmations: observation.confirmations,
      transactionId: observation.txid,
      outputIndex: observation.vout,
      isLate:
          presentationMarksLate ||
          !invoiceExpiresAt.isAfter(firstSeenAt) ||
          invoiceStatus == InvoiceStatus.cancelled,
      problem: eventState == InvoicePaymentEventState.problem
          ? invoicePaymentProblemFromWire(observation.state) ??
                InvoicePaymentProblem.unknown
          : null,
    );
  }

  InvoicePayerAmount? _toPayerAmount(
    PaymentMethod rail, {
    required int? payerAmountSat,
    required int merchantTargetAmountSat,
  }) {
    if (payerAmountSat == null) return null;
    return InvoicePayerAmount(
      rail: rail,
      merchantTargetAmountSat: merchantTargetAmountSat,
      payerAmountSat: payerAmountSat,
    );
  }

  InvoicePaymentEvent? _toAggregatePaymentEvent(
    BullnymInvoiceStatus status, {
    required InvoiceStatus invoiceStatus,
    required InvoiceSettlementState invoiceSettlement,
    required DateTime invoiceExpiresAt,
  }) {
    final rail = PaymentMethod.fromWire(status.paidVia);
    if (rail == null ||
        status.paidAtUnix == null ||
        status.paidAmountSat == null) {
      return null;
    }
    final paidAt = _fromUnix(status.paidAtUnix!);
    final eventState = switch (invoiceSettlement) {
      InvoiceSettlementState.settled => InvoicePaymentEventState.settled,
      InvoiceSettlementState.problem => InvoicePaymentEventState.problem,
      InvoiceSettlementState.none ||
      InvoiceSettlementState.pending => InvoicePaymentEventState.pending,
    };
    return InvoicePaymentEvent(
      rail: rail,
      amountSat: status.paidAmountSat!,
      firstSeenAt: paidAt,
      lastSeenAt: paidAt,
      state: eventState,
      confirmations: 0,
      isLate:
          invoicePresentationMarksLate(status.presentationStatus) ||
          !invoiceExpiresAt.isAfter(paidAt) ||
          invoiceStatus == InvoiceStatus.cancelled,
      problem: eventState == InvoicePaymentEventState.problem
          ? invoicePaymentProblemFromWire(status.settlementStatus) ??
                invoicePaymentProblemFromWire(
                  status.presentationStatus ?? '',
                ) ??
                InvoicePaymentProblem.unknown
          : null,
    );
  }

  bool _statusCarriesPaymentEvidence(InvoiceStatus status) =>
      status == InvoiceStatus.inProgress ||
      status == InvoiceStatus.partiallyPaid ||
      status == InvoiceStatus.paid ||
      status == InvoiceStatus.underpaid ||
      status == InvoiceStatus.overpaid;

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
