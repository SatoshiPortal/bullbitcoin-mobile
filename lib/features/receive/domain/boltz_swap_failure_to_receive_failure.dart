import 'package:receive/receive.dart';
import 'package:swaps/swaps.dart';

extension BoltzSwapFailureToReceiveFailure on SwapsFailure {
  ReceiveFailure toReceiveFailure({required int amountSat}) => switch (this) {
    final SwapsAmountOutOfLimitsFailure limits =>
      ReceiveAmountOutOfBoundsFailure(
        limitAmountSat: BigInt.from(
          limits.isBelowMinimum(amountSat) ? limits.minSat : limits.maxSat,
        ),
        isMinimum: limits.isBelowMinimum(amountSat),
        logMessage: logMessage,
      ),
    SwapsBoltzUnavailableFailure() ||
    SwapsNetworkFailure() => ReceiveNetworkFailure(logMessage),
    SwapsBoltzRejectedFailure() => ReceiveSwapUnavailableFailure(logMessage),
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
    SwapsUnexpectedFailure() ||
    AutoswapFailure() => ReceiveUnexpectedFailure(logMessage),
  };
}
