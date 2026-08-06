import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';

class CreateReceiveOrderSwapUsecase {
  final SwapFacade _swapFacade;
  final GetReceiveAddressUsecase _getReceiveAddressUsecase;
  final DateTime Function() _now;
  final Future<PaymentRequest> Function(String) _parsePaymentRequest;

  CreateReceiveOrderSwapUsecase(
    this._swapFacade,
    this._getReceiveAddressUsecase, {
    DateTime Function()? now,
    Future<PaymentRequest> Function(String)? parsePaymentRequest,
  }) : _now = now ?? DateTime.now,
       _parsePaymentRequest = parsePaymentRequest ?? PaymentRequest.parse;

  Future<Result<OrderSwapRecord, ReceiveFailure>> execute({
    required Wallet wallet,
    required int amountSat,
    String? note,
  }) async {
    if (!wallet.isLiquid || amountSat <= 0) {
      return const Err(ReceiveSwapUnavailableFailure());
    }
    final environment = wallet.isTestnet
        ? OrderSwapEnvironment.testnet
        : OrderSwapEnvironment.mainnet;

    final quoteResult = await _swapFacade.getQuote(
      environment: environment,
      amountSat: BigInt.from(amountSat),
      isInAmountFixed: true,
      inNetwork: OrderSwapNetwork.lightning,
      outNetwork: OrderSwapNetwork.liquid,
    );
    final OrderSwapQuote quote;
    switch (quoteResult) {
      case Ok(:final value):
        quote = value;
      case Err(:final failure):
        log.warning('[ReceiveOrderSwap] quote failed (${failure.runtimeType})');
        return Err(_mapFailure(failure));
    }
    if (quote.inAmountSat != BigInt.from(amountSat)) {
      return const Err(
        ReceiveUnexpectedFailure('Exchange quote changed the fixed amount'),
      );
    }

    try {
      final destination = await _getReceiveAddressUsecase.execute(
        walletId: wallet.id,
        generateNew: false,
      );
      final createResult = await _swapFacade.createOrder(
        amountSat: BigInt.from(amountSat),
        isInAmountFixed: true,
        inNetwork: OrderSwapNetwork.lightning,
        outNetwork: OrderSwapNetwork.liquid,
        destinationAddress: destination.address,
        fallbackAddress: null,
        purpose: OrderSwapPurpose.receiveLightning,
        environment: environment,
        destinationWalletId: wallet.id,
        note: note,
      );
      final OrderSwapRecord record;
      switch (createResult) {
        case Ok(:final value):
          record = value;
        case Err(:final failure):
          log.warning(
            '[ReceiveOrderSwap] create failed (${failure.runtimeType})',
          );
          return Err(_mapFailure(failure));
      }
      final invoice = record.order?.lightningInvoice;
      if (invoice == null || invoice.isEmpty) {
        log.warning('[ReceiveOrderSwap] create returned no invoice');
        return const Err(
          ReceiveInvalidInvoiceFailure(
            'Exchange order did not return a Lightning invoice',
          ),
        );
      }
      final request = await _parsePaymentRequest(invoice);
      if (request is! Bolt11PaymentRequest ||
          request.isTestnet != wallet.isTestnet ||
          request.amountSat != amountSat) {
        log.warning('[ReceiveOrderSwap] create returned an invalid invoice');
        return const Err(
          ReceiveInvalidInvoiceFailure(
            'Exchange returned an invalid Lightning invoice',
          ),
        );
      }
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        request.expiresAt * 1000,
        isUtc: true,
      );
      final deadline = record.order!.confirmationDeadline.toUtc();
      final deadlineAtInvoicePrecision = DateTime.fromMillisecondsSinceEpoch(
        deadline.millisecondsSinceEpoch ~/ 1000 * 1000,
        isUtc: true,
      );
      if (!expiresAt.isAfter(_now().toUtc()) ||
          expiresAt.isBefore(deadlineAtInvoicePrecision)) {
        log.warning(
          '[ReceiveOrderSwap] invoice expires before the order deadline',
        );
        return const Err(
          ReceiveInvalidInvoiceFailure(
            'Exchange invoice expires before the order deadline',
          ),
        );
      }
      return Ok(record);
    } catch (error) {
      log.severe(
        message: '[ReceiveOrderSwap] failed (${error.runtimeType})',
        error: error.runtimeType,
        trace: StackTrace.current,
      );
      return Err(ReceiveUnexpectedFailure(error.toString()));
    }
  }

  ReceiveFailure _mapFailure(SwapFailure failure) => switch (failure) {
    SwapAmountOutOfBoundsFailure(
      :final limitAmountSat,
      :final isMinimum,
      :final logMessage,
    ) =>
      ReceiveAmountOutOfBoundsFailure(
        limitAmountSat: limitAmountSat,
        isMinimum: isMinimum,
        logMessage: logMessage,
      ),
    SwapNoPaymentOptionFailure() ||
    SwapValidationFailure() ||
    SwapRateLimitedFailure() ||
    SwapProviderFailure() => ReceiveSwapUnavailableFailure(failure.logMessage),
    SwapNetworkFailure() ||
    SwapTimeoutFailure() => ReceiveNetworkFailure(failure.logMessage),
    SwapOrderNotFoundFailure() ||
    SwapOrderExpiredFailure() ||
    SwapCreationUnknownFailure() ||
    SwapInvalidStateFailure() ||
    SwapStorageFailure() ||
    SwapUnexpectedFailure() => ReceiveUnexpectedFailure(failure.logMessage),
  };
}
