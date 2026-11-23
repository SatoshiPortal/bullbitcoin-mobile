import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:primitives/primitives.dart';
import 'package:satoshifier/payment_request.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:address_view/address_view.dart';
import 'package:receive/receive.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';

class CreateReceiveOrderSwapUsecase {
  final SwapFacade _swapFacade;
  final AddressView _addresses;
  final DateTime Function() _now;
  final Future<PaymentRequest> Function(String) _parsePaymentRequest;

  CreateReceiveOrderSwapUsecase(
    this._swapFacade,
    this._addresses, {
    DateTime Function()? now,
    Future<PaymentRequest> Function(String)? parsePaymentRequest,
  }) : _now = now ?? DateTime.now,
       _parsePaymentRequest = parsePaymentRequest ?? PaymentRequest.parse;

  @useResult
  Future<Result<OrderSwapRecord, ReceiveFailure>> execute({
    required Wallet wallet,
    required int amountSat,
    String? note,
  }) async {
    if (!NetworkCapabilities.supports(
          wallet.network.shared,
          NetworkCapability.swaps,
        ) ||
        !NetworkCapabilities.supports(
          wallet.network.shared,
          NetworkCapability.exchange,
        )) {
      log.warning('Capability refused feature=receive_swap reason=unsupported');
      return const Err(ReceiveSwapUnavailableFailure());
    }
    if (!wallet.isLiquid || amountSat <= 0) {
      return const Err(ReceiveSwapUnavailableFailure());
    }
    final environment = wallet.network.requireHistoricalTestnet()
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
      final WalletAddress destination;
      switch (await _addresses.receiveAddress(
        walletId: wallet.id,
        advance: true,
      )) {
        case Err():
          return const Err(ReceiveAddressUnavailableFailure());
        case Ok(:final value):
          destination = value;
      }
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
        quotedCounterpartAmountSat: quote.outAmountSat,
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
      final order = record.order;
      final invoice = order?.lightningInvoice;
      if (order == null || invoice == null || invoice.isEmpty) {
        log.warning('[ReceiveOrderSwap] create returned no invoice');
        return const Err(
          ReceiveInvalidInvoiceFailure(
            'Exchange order did not return a Lightning invoice',
          ),
        );
      }
      final request = await _parsePaymentRequest(invoice);
      if (request is! Bolt11PaymentRequest ||
          request.isTestnet != wallet.network.requireHistoricalTestnet() ||
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
      final deadline = order.confirmationDeadline.toUtc();
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
    SwapNoPaymentOptionFailure(:final inNetwork, :final outNetwork) =>
      ReceiveSwapRouteUnavailableFailure(
        inNetwork: inNetwork,
        outNetwork: outNetwork,
        logMessage: failure.logMessage,
      ),
    SwapUnsupportedNetworkFailure() ||
    SwapValidationFailure() ||
    SwapProviderFailure() => ReceiveSwapUnavailableFailure(failure.logMessage),
    SwapRateLimitedFailure(:final retryAfter) => ReceiveRateLimitedFailure(
      retryAfter: retryAfter,
      logMessage: failure.logMessage,
    ),
    SwapNetworkFailure() ||
    SwapTimeoutFailure() => ReceiveNetworkFailure(failure.logMessage),
    SwapOrderNotFoundFailure() ||
    SwapOrderExpiredFailure() ||
    SwapCreationUnknownFailure() ||
    SwapOrderMismatchFailure() ||
    SwapInvalidStateFailure() ||
    SwapStorageFailure() ||
    SwapUnexpectedFailure() => ReceiveUnexpectedFailure(failure.logMessage),
    SwapPriceUnavailableFailure() => ReceivePriceUnavailableFailure(
      failure.logMessage,
    ),
  };
}
