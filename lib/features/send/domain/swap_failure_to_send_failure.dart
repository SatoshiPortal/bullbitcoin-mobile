import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';

SendFailure mapSwapFailureToSendFailure(SwapFailure failure) =>
    switch (failure) {
      SwapAmountOutOfBoundsFailure(:final limitAmountSat, :final isMinimum) =>
        SendAmountOutOfBoundsFailure(
          minimumSat: isMinimum == true ? limitAmountSat : null,
          maximumSat: isMinimum == false ? limitAmountSat : null,
          logMessage: failure.logMessage,
        ),
      SwapValidationFailure() => SendInvalidPaymentRequestFailure(
        logMessage: failure.logMessage,
      ),
      SwapNoPaymentOptionFailure() ||
      SwapOrderExpiredFailure() ||
      SwapCreationUnknownFailure() ||
      SwapInvalidStateFailure() ||
      SwapRateLimitedFailure() ||
      SwapProviderFailure() ||
      SwapNetworkFailure() ||
      SwapTimeoutFailure() ||
      SwapStorageFailure() ||
      SwapOrderNotFoundFailure() ||
      SwapUnexpectedFailure() => SendSwapCreationFailure(failure.logMessage),
    };
