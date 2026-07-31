import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_failure.dart';
import 'package:meta/meta.dart';

/// Fee presets for the sweep screen.
///
/// Thin wrapper whose only job is to turn the shared core use-case's thrown
/// exception into a modeled [SweepFailure], so the cubit never catches infra.
class GetSweepFeesUsecase {
  final GetNetworkFeesUsecase _getNetworkFees;

  GetSweepFeesUsecase({required GetNetworkFeesUsecase getNetworkFeesUsecase})
    : _getNetworkFees = getNetworkFeesUsecase;

  @useResult
  Future<Result<FeeOptions, SweepFailure>> execute() async {
    try {
      // Sweep is Bitcoin-only: Liquid needs LWK's rate-only contract, which
      // this flow does not implement.
      final fees = await _getNetworkFees.execute(isLiquid: false);
      return Ok(fees);
    } on Exception catch (e, st) {
      log.warning(
        'Failed to fetch network fees for sweep',
        error: e,
        trace: st,
      );
      return Err(SweepFeesUnavailableFailure(e.toString()));
    }
  }
}
