import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Pay's boundary onto the shared fee-preset read, which still throws.
class LoadPayNetworkFeesUsecase {
  final GetNetworkFeesUsecase _getNetworkFeesUsecase;

  const LoadPayNetworkFeesUsecase({required this._getNetworkFeesUsecase});

  @useResult
  Future<Result<FeeOptions, PayFailure>> execute({
    required bool isLiquid,
  }) async {
    try {
      return Ok(await _getNetworkFeesUsecase.execute(isLiquid: isLiquid));
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
