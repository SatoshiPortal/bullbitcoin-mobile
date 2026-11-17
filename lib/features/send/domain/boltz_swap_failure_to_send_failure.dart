import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:swaps/swaps.dart';

extension BoltzSwapFailureToSendFailure on SwapsFailure {
  SendFailure toSendFailure({required int amountSat}) => switch (this) {
    final SwapsAmountOutOfLimitsFailure limits => SendAmountOutOfBoundsFailure(
      minimumSat: limits.isBelowMinimum(amountSat)
          ? BigInt.from(limits.minSat)
          : null,
      maximumSat: limits.isBelowMinimum(amountSat)
          ? null
          : BigInt.from(limits.maxSat),
      logMessage: logMessage,
    ),
    SwapsBoltzUnavailableFailure() ||
    SwapsBoltzRejectedFailure() ||
    SwapsNetworkFailure() ||
    SwapsMasterKeyUnavailableFailure() ||
    SwapsNotRestorableFailure() ||
    SwapsRefundNotFinalFailure() => SendSwapCreationFailure(logMessage),
    SwapsUnexpectedFailure() => SendUnexpectedFailure(logMessage),
  };
}
