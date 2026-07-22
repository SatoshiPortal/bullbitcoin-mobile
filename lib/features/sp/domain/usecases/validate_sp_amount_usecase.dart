import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_balance_usecase.dart';

/// Validates a send amount against the available balance. Rust `prepare()`
/// stays the authority on fee-inclusive feasibility and coin selection; this is
/// the up-front UX check that blocks advancing on an obviously bad amount.
class ValidateSpAmountUsecase {
  final GetSpBalanceUsecase _getSpBalanceUsecase;

  ValidateSpAmountUsecase({required this._getSpBalanceUsecase});

  Result<BigInt, SpFailure> execute(BigInt sats) {
    if (sats <= BigInt.zero) return const Err(SpAmountBelowMinimum());
    final available = _availableBalance();
    if (available != null && sats > available) {
      return const Err(SpAmountExceedsBalance());
    }
    return Ok(sats);
  }

  // Snapshot balance for the ceiling check. A null result (no session, or the
  // scan holds the inner lock) skips the ceiling; Rust prepare() stays the
  // authority on feasibility.
  BigInt? _availableBalance() {
    try {
      return _getSpBalanceUsecase.execute().totalUnifiedSat;
    } catch (e) {
      log.warning('ValidateSpAmountUsecase: balance read failed: $e');
      return null;
    }
  }
}
