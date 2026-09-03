import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The absolute fee, in sats, that a built pay payin actually pays.
class CalculatePayAbsoluteFeesUsecase {
  final CalculateBitcoinAbsoluteFeesUsecase
  _calculateBitcoinAbsoluteFeesUsecase;
  final CalculateLiquidAbsoluteFeesUsecase _calculateLiquidAbsoluteFeesUsecase;

  const CalculatePayAbsoluteFeesUsecase({
    required this._calculateBitcoinAbsoluteFeesUsecase,
    required this._calculateLiquidAbsoluteFeesUsecase,
  });

  @useResult
  Future<Result<int, PayFailure>> bitcoin({required String psbt}) async {
    try {
      return Ok(await _calculateBitcoinAbsoluteFeesUsecase.execute(psbt: psbt));
    } catch (e, st) {
      log.severe(
        message: 'Failed to read the absolute fees of a pay payin PSBT',
        error: e,
        trace: st,
      );
      return Err(PayUnexpectedFailure('$e'));
    }
  }

  @useResult
  Future<Result<int, PayFailure>> liquid({required String pset}) async {
    try {
      return Ok(await _calculateLiquidAbsoluteFeesUsecase.execute(pset: pset));
    } catch (e, st) {
      log.severe(
        message: 'Failed to read the absolute fees of a pay payin PSET',
        error: e,
        trace: st,
      );
      return Err(PayUnexpectedFailure('$e'));
    }
  }
}
