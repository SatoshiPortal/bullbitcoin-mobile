import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:boltz_swaps/boltz_swaps.dart';

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
    SwapsMasterKeyUnavailableFailure() ||
    SwapsNotRestorableFailure() ||
    SwapsRefundNotFinalFailure() ||
    SwapsUnexpectedFailure() => ReceiveUnexpectedFailure(logMessage),
  };
}
