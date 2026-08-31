import 'package:bull_swap/src/domain/created_swap.dart';
import 'package:bull_swap/src/domain/swap_failure.dart';
import 'package:bull_swap/src/domain/swap_network.dart';
import 'package:bull_swap/src/domain/swap_provider_config.dart';
import 'package:bull_swap/src/domain/swap_quote.dart';
import 'package:bull_swap/src/domain/swap_status.dart';
import 'package:primitives/primitives.dart';

abstract interface class SwapProvider {
  SwapProviderConfig get config;

  Future<Result<SwapQuote, SwapFailure>> quote({
    required SwapNetwork inNetwork,
    required SwapNetwork outNetwork,
    required BigInt amountSat,
    required bool isInAmountFixed,
    required SwapEnvironment environment,
  });

  Future<Result<CreatedSwap, SwapFailure>> createLnSend({
    required SwapNetwork fromNetwork,
    required String invoice,
    required String refundAddress,
    String? sourceWalletId,
    required SwapEnvironment environment,
  });

  Future<Result<CreatedSwap, SwapFailure>> createLnReceive({
    required SwapNetwork toNetwork,
    required BigInt amountSat,
    required String payoutAddress,
    String? destinationWalletId,
    required SwapEnvironment environment,
  });

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
  });

  Future<Result<SwapStatusUpdate, SwapFailure>> refresh(
    String swapId, {
    required SwapEnvironment environment,
  });

  Stream<SwapStatusUpdate> watch(
    String swapId, {
    required SwapEnvironment environment,
  });
}

abstract interface class ClaimRefundCapable {
  Future<Result<String, SwapFailure>> claim(
    String swapId, {
    required SwapEnvironment environment,
  });

  Future<Result<String, SwapFailure>> refund(
    String swapId, {
    required SwapEnvironment environment,
  });
}
