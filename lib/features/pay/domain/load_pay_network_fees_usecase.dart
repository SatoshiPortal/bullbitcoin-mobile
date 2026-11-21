import 'package:fees/fees.dart';
import 'package:bb_mobile/features/fees/public/app_fee_estimates.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Pay's boundary onto the shared fee-preset read, which still throws.
class LoadPayNetworkFeesUsecase {
  final AppFeeEstimates _feeEstimates;

  const LoadPayNetworkFeesUsecase({required this._feeEstimates});

  @useResult
  Future<Result<FeeOptions, PayFailure>> execute({
    required bool isLiquid,
  }) async {
    try {
      return Ok(await _feeEstimates.execute(isLiquid: isLiquid));
    } catch (e, st) {
      log.severe(
        message: 'Failed to load the network fees',
        error: e,
        trace: st,
      );
      // Actionable: the fee cannot be picked, and retrying is the whole cure.
      return Err(PayFeesUnavailableFailure('$e'));
    }
  }
}
