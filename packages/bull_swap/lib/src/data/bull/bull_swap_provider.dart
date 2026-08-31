import 'dart:async';

import 'package:bull_swap/src/data/bull/exchange_models.dart';
import 'package:bull_swap/src/data/bull/exchange_public_api_datasource.dart';
import 'package:bull_swap/src/data/bull/order_swap_amount_codec.dart';
import 'package:bull_swap/src/domain/created_swap.dart';
import 'package:bull_swap/src/domain/swap_failure.dart';
import 'package:bull_swap/src/domain/order_swap_network.dart';
import 'package:bull_swap/src/domain/swap_network.dart';
import 'package:bull_swap/src/domain/swap_provider.dart';
import 'package:bull_swap/src/domain/swap_provider_config.dart';
import 'package:bull_swap/src/domain/swap_quote.dart';
import 'package:bull_swap/src/domain/swap_status.dart';
import 'package:primitives/primitives.dart';

class BullSwapProvider implements SwapProvider {
  @override
  final SwapProviderConfig config;
  final ExchangePublicApiDatasource _testnet;
  final ExchangePublicApiDatasource _mainnet;
  final Duration pollInterval;

  BullSwapProvider(
    this._testnet,
    this._mainnet, {
    required this.config,
    this.pollInterval = const Duration(seconds: 5),
  });

  ExchangePublicApiDatasource _remote(SwapEnvironment env) =>
      env == SwapEnvironment.testnet ? _testnet : _mainnet;

  @override
  Future<Result<SwapQuote, SwapFailure>> quote({
    required SwapNetwork inNetwork,
    required SwapNetwork outNetwork,
    required BigInt amountSat,
    required bool isInAmountFixed,
    required SwapEnvironment environment,
  }) async {
    try {
      final model = await _remote(environment).getBestSwapOption(
        amountSat: amountSat,
        isInAmountFixed: isInAmountFixed,
        inNetwork: OrderSwapNetwork.fromSwapNetwork(inNetwork),
        outNetwork: OrderSwapNetwork.fromSwapNetwork(outNetwork),
      );
      final payin = orderSwapAmountToSats(model.inAmount);
      final payout = orderSwapAmountToSats(model.outAmount);
      return Ok(
        SwapQuote(
          providerId: config.id,
          inNetwork: inNetwork,
          outNetwork: outNetwork,
          payinAmountSat: payin,
          payoutAmountSat: payout,
          feesSat: payin > payout ? payin - payout : BigInt.zero,
        ),
      );
    } catch (error) {
      return Err(
        _mapFailure(error, inNetwork: inNetwork, outNetwork: outNetwork),
      );
    }
  }

  @override
  Future<Result<CreatedSwap, SwapFailure>> createLnSend({
    required SwapNetwork fromNetwork,
    required String invoice,
    required String refundAddress,
    String? sourceWalletId,
    required SwapEnvironment environment,
  }) => _create(
    environment: environment,
    inNetwork: fromNetwork,
    outNetwork: SwapNetwork.lightning,
    amountSat: BigInt.zero,
    isInAmountFixed: false,
    destinationAddress: invoice,
    fallbackAddress: refundAddress,
  );

  @override
  Future<Result<CreatedSwap, SwapFailure>> createLnReceive({
    required SwapNetwork toNetwork,
    required BigInt amountSat,
    required String payoutAddress,
    String? destinationWalletId,
    required SwapEnvironment environment,
  }) => _create(
    environment: environment,
    inNetwork: SwapNetwork.lightning,
    outNetwork: toNetwork,
    amountSat: amountSat,
    isInAmountFixed: false,
    destinationAddress: payoutAddress,
    fallbackAddress: null,
  );

  @override
  Future<Result<CreatedSwap, SwapFailure>> createChainSwap({
    required SwapNetwork fromNetwork,
    required SwapNetwork toNetwork,
    required BigInt amountSat,
    required bool isInAmountFixed,
    required String payoutAddress,
    required String refundAddress,
    String? sourceWalletId,
    String? destinationWalletId,
    required SwapEnvironment environment,
  }) => _create(
    environment: environment,
    inNetwork: fromNetwork,
    outNetwork: toNetwork,
    amountSat: amountSat,
    isInAmountFixed: isInAmountFixed,
    destinationAddress: payoutAddress,
    fallbackAddress: refundAddress,
  );

  Future<Result<CreatedSwap, SwapFailure>> _create({
    required SwapEnvironment environment,
    required SwapNetwork inNetwork,
    required SwapNetwork outNetwork,
    required BigInt amountSat,
    required bool isInAmountFixed,
    required String destinationAddress,
    required String? fallbackAddress,
  }) async {
    try {
      final model = await _remote(environment).createOrderSwap(
        amountSat: amountSat,
        isInAmountFixed: isInAmountFixed,
        inNetwork: OrderSwapNetwork.fromSwapNetwork(inNetwork),
        outNetwork: OrderSwapNetwork.fromSwapNetwork(outNetwork),
        destinationAddress: destinationAddress,
        fallbackAddress: fallbackAddress,
      );
      return Ok(_toCreatedSwap(model, environment, inNetwork, outNetwork));
    } catch (error) {
      return Err(
        _mapFailure(error, inNetwork: inNetwork, outNetwork: outNetwork),
      );
    }
  }

  @override
  Future<Result<SwapStatusUpdate, SwapFailure>> refresh(
    String swapId, {
    required SwapEnvironment environment,
  }) async {
    try {
      final model = await _remote(environment).getOrderSwapSummary(swapId);
      return Ok(_toStatusUpdate(model));
    } catch (error) {
      return Err(_mapFailure(error));
    }
  }

  @override
  Stream<SwapStatusUpdate> watch(
    String swapId, {
    required SwapEnvironment environment,
  }) async* {
    while (true) {
      final result = await refresh(swapId, environment: environment);
      if (result case Ok(:final value)) {
        yield value;
        if (value.status.isTerminal) return;
      }
      await Future<void>.delayed(pollInterval);
    }
  }

  CreatedSwap _toCreatedSwap(
    OrderSwapModel model,
    SwapEnvironment environment,
    SwapNetwork inNetwork,
    SwapNetwork outNetwork,
  ) {
    final payinAddress = switch (inNetwork) {
      SwapNetwork.bitcoin => model.bitcoinAddress,
      SwapNetwork.liquid => model.liquidAddress,
      SwapNetwork.lightning => null,
    };
    return CreatedSwap(
      providerId: config.id,
      swapId: model.orderId,
      environment: environment,
      inNetwork: inNetwork,
      outNetwork: outNetwork,
      payinAmountSat: orderSwapAmountToSats(model.payinAmount),
      payoutAmountSat: orderSwapAmountToSats(model.payoutAmount),
      payinAddress: payinAddress,
      payinInvoice: model.lightningInvoice,
      payoutAddress: null,
      expiresAt: model.confirmationDeadline,
    );
  }

  SwapStatusUpdate _toStatusUpdate(OrderSwapModel model) => SwapStatusUpdate(
    swapId: model.orderId,
    status: _lifecycle(model),
    payinTxId: model.bitcoinTransactionId ?? model.liquidTransactionId,
    payoutTxId: null,
  );

  SwapLifecycleStatus _lifecycle(OrderSwapModel model) {
    final order = model.orderStatus.trim().toLowerCase();
    final payout = model.payoutStatus.trim().toLowerCase();
    final payin = model.payinStatus.trim().toLowerCase();
    const failed = {'failed', 'rejected', 'cancelled', 'canceled'};
    if (payout == 'completed' || order == 'completed') {
      return SwapLifecycleStatus.completed;
    }
    if (payout == 'refunded' || order == 'refunded') {
      return SwapLifecycleStatus.refunded;
    }
    if (order == 'expired' || order == 'payment deadline expired') {
      return SwapLifecycleStatus.expired;
    }
    if (failed.contains(payout) || failed.contains(order)) {
      return SwapLifecycleStatus.failed;
    }
    if (payin == 'completed') return SwapLifecycleStatus.payoutInProgress;
    if (payin.isNotEmpty && payin != 'pending') {
      return SwapLifecycleStatus.payinDetected;
    }
    return SwapLifecycleStatus.awaitingPayin;
  }

  SwapFailure _mapFailure(
    Object error, {
    SwapNetwork? inNetwork,
    SwapNetwork? outNetwork,
  }) {
    if (error is ExchangeRateLimitException) {
      return SwapRateLimitedFailure(
        retryAfter: error.retryAfterSeconds == null
            ? null
            : Duration(seconds: error.retryAfterSeconds!),
      );
    }
    if (error is ExchangeProviderUnavailableException) {
      return const SwapProviderUnavailableFailure('Swap provider unavailable');
    }
    if (error is ExchangeTimeoutException) {
      return SwapTimeoutFailure(error.logMessage);
    }
    if (error is ExchangeNetworkException) {
      return SwapNetworkFailure(error.logMessage);
    }
    if (error is ExchangeRpcException) {
      return switch (error.apiCode) {
        'ERR_ORD_PO404' => SwapNoPaymentOptionFailure(
          inNetwork: inNetwork,
          outNetwork: outNetwork,
          logMessage: error.logMessage,
        ),
        'ERR_ORD_LMT001' => SwapAmountOutOfBoundsFailure(
          limitAmountSat: error.limit == null
              ? null
              : orderSwapAmountToSats(error.limit!),
          isMinimum: switch (error.limitOperator) {
            'greater than or equal' => true,
            'less than or equal' => false,
            _ => null,
          },
          logMessage: error.logMessage,
        ),
        'ERR_ORD_404' => SwapOrderNotFoundFailure(error.logMessage),
        _ => SwapProviderFailure(error.apiCode ?? error.logMessage),
      };
    }
    if (error is ExchangeResponseException) {
      return SwapProviderFailure(error.logMessage);
    }
    if (error is ArgumentError || error is FormatException) {
      return SwapValidationFailure(logMessage: error.toString());
    }
    return SwapUnexpectedFailure(error.toString());
  }
}
