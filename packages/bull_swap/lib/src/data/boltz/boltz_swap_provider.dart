import 'package:bull_swap/src/domain/boltz_engine_port.dart';
import 'package:bull_swap/src/domain/created_swap.dart';
import 'package:bull_swap/src/domain/swap_failure.dart';
import 'package:bull_swap/src/domain/swap_network.dart';
import 'package:bull_swap/src/domain/swap_provider.dart';
import 'package:bull_swap/src/domain/swap_provider_config.dart';
import 'package:bull_swap/src/domain/swap_quote.dart';
import 'package:bull_swap/src/domain/swap_status.dart';
import 'package:primitives/primitives.dart';

class BoltzSwapProvider implements SwapProvider, ClaimRefundCapable {
  @override
  final SwapProviderConfig config;
  final BoltzEnginePort _engine;

  BoltzSwapProvider(this._engine, {required this.config});

  @override
  Future<Result<SwapQuote, SwapFailure>> quote({
    required SwapNetwork inNetwork,
    required SwapNetwork outNetwork,
    required BigInt amountSat,
    required bool isInAmountFixed,
    required SwapEnvironment environment,
  }) => _engine.quote(
    inNetwork: inNetwork,
    outNetwork: outNetwork,
    amountSat: amountSat,
    isInAmountFixed: isInAmountFixed,
    environment: environment,
  );

  @override
  Future<Result<CreatedSwap, SwapFailure>> createLnSend({
    required SwapNetwork fromNetwork,
    required String invoice,
    required String refundAddress,
    String? sourceWalletId,
    required SwapEnvironment environment,
  }) => _engine.createLnSend(
    fromNetwork: fromNetwork,
    invoice: invoice,
    refundAddress: refundAddress,
    sourceWalletId: sourceWalletId,
    environment: environment,
  );

  @override
  Future<Result<CreatedSwap, SwapFailure>> createLnReceive({
    required SwapNetwork toNetwork,
    required BigInt amountSat,
    required String payoutAddress,
    String? destinationWalletId,
    required SwapEnvironment environment,
  }) => _engine.createLnReceive(
    toNetwork: toNetwork,
    amountSat: amountSat,
    payoutAddress: payoutAddress,
    destinationWalletId: destinationWalletId,
    environment: environment,
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
  }) => _engine.createChainSwap(
    fromNetwork: fromNetwork,
    toNetwork: toNetwork,
    amountSat: amountSat,
    isInAmountFixed: isInAmountFixed,
    payoutAddress: payoutAddress,
    refundAddress: refundAddress,
    sourceWalletId: sourceWalletId,
    destinationWalletId: destinationWalletId,
    environment: environment,
  );

  @override
  Future<Result<SwapStatusUpdate, SwapFailure>> refresh(
    String swapId, {
    required SwapEnvironment environment,
  }) => _engine.refresh(swapId, environment: environment);

  @override
  Stream<SwapStatusUpdate> watch(
    String swapId, {
    required SwapEnvironment environment,
  }) => _engine.watch(swapId, environment: environment);

  @override
  Future<Result<String, SwapFailure>> claim(
    String swapId, {
    required SwapEnvironment environment,
  }) => _engine.claim(swapId, environment: environment);

  @override
  Future<Result<String, SwapFailure>> refund(
    String swapId, {
    required SwapEnvironment environment,
  }) => _engine.refund(swapId, environment: environment);
}
