import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:boltz_swaps/boltz_swaps.dart';

extension SwapsFailureToSwapFailure on SwapsFailure {
  SwapFailure toSwapFailure({required int amountSat}) => switch (this) {
    SwapsAmountOutOfLimitsFailure(:final minSat, :final maxSat) =>
      SwapAmountOutOfBoundsFailure(
        limitAmountSat: BigInt.from(amountSat < minSat ? minSat : maxSat),
        isMinimum: amountSat < minSat,
      ),
    SwapsBoltzUnavailableFailure() ||
    SwapsNetworkFailure() => SwapNetworkFailure(logMessage),
    SwapsBoltzRejectedFailure() => SwapProviderFailure(logMessage),
    SwapsMasterKeyUnavailableFailure() ||
    SwapsNotRestorableFailure() ||
    SwapsRefundNotFinalFailure() ||
    SwapsUnexpectedFailure() => SwapUnexpectedFailure(logMessage),
  };
}
