import 'package:bb_mobile/core/primitives/swap_network_payment_network_x.dart';
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
      SwapNoPaymentOptionFailure(:final inNetwork, :final outNetwork) =>
        SendSwapRouteUnavailableFailure(
          inNetwork: inNetwork?.toPaymentNetwork,
          outNetwork: outNetwork?.toPaymentNetwork,
          logMessage: failure.logMessage,
        ),
      SwapOrderExpiredFailure() ||
      SwapCreationUnknownFailure() ||
      SwapOrderMismatchFailure() ||
      SwapInvalidStateFailure() ||
      SwapProviderFailure() ||
      SwapProviderUnavailableFailure() ||
      SwapProviderMisconfiguredFailure() ||
      SwapSwitchBlockedFailure() ||
      SwapNetworkFailure() ||
      SwapTimeoutFailure() ||
      SwapStorageFailure() ||
      SwapOrderNotFoundFailure() ||
      SwapUnexpectedFailure() => SendSwapCreationFailure(failure.logMessage),
      SwapRateLimitedFailure(:final retryAfter) => SendRateLimitedFailure(
        retryAfter: retryAfter,
        logMessage: failure.logMessage,
      ),
    };
