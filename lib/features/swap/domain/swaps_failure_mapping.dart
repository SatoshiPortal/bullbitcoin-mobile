import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:swaps/swaps.dart';

extension SwapsFailureToSwapFailure on SwapsFailure {
  SwapFailure toSwapFailure({required int amountSat}) => switch (this) {
    final SwapsAmountOutOfLimitsFailure limits => SwapAmountOutOfBoundsFailure(
      limitAmountSat: BigInt.from(
        limits.isBelowMinimum(amountSat) ? limits.minSat : limits.maxSat,
      ),
      isMinimum: limits.isBelowMinimum(amountSat),
    ),
    SwapsBoltzUnavailableFailure() ||
    SwapsNetworkFailure() => SwapNetworkFailure(logMessage),
    SwapsBoltzRejectedFailure() => SwapProviderFailure(logMessage),
    SwapsBusyFailure() ||
    SwapsAuthorizationFailure() ||
    SwapsMasterKeyUnavailableFailure() ||
    SwapsNotRestorableFailure() ||
    SwapsRefundNotFinalFailure() ||
    SwapsUnsupportedNetworkFailure() ||
    SwapsInvalidServerFailure() ||
    SwapsInvalidAutoSwapSettingsFailure() ||
    SwapsInvalidLockupFailure() ||
    SwapsStorageFailure() ||
    SwapsUnexpectedFailure() => SwapUnexpectedFailure(logMessage),
  };
}
