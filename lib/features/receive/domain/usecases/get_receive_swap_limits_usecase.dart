import 'package:bb_mobile/features/receive/domain/boltz_swap_failure_to_receive_failure.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/swaps.dart';

/// Loads the published Boltz limits for the admitted destination chain.
class GetReceiveSwapLimitsUsecase {
  final GetSwapLimitsAndFeesUsecase _getLimits;

  const GetReceiveSwapLimitsUsecase(this._getLimits);

  Future<Result<SwapLimits, ReceiveFailure>> execute({
    required bool isLiquid,
  }) async {
    return switch (await _getLimits.execute(
      isLiquid ? SwapType.lightningToLiquid : SwapType.lightningToBitcoin,
    )) {
      Ok(:final value) => Ok(value.$1),
      Err(:final failure) => Err(failure.toReceiveFailure(amountSat: 0)),
    };
  }
}
