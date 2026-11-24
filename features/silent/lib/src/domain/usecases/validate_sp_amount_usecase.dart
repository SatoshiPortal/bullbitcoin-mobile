import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:silent/src/domain/usecases/get_sp_balance_usecase.dart';

/// Validates a send amount against the available balance. Rust `prepare()`
/// stays the authority on fee-inclusive feasibility and coin selection; this is
/// the up-front UX check that blocks advancing on an obviously bad amount.
class ValidateSpAmountUsecase {
  final GetSpBalanceUsecase _getSpBalanceUsecase;

  ValidateSpAmountUsecase({required this._getSpBalanceUsecase});

  Result<Sats, SilentFailure> execute(Sats sats) {
    if (sats.value <= BigInt.zero) return const Err(SilentAmountBelowMinimum());
    final Sats available;
    switch (_getSpBalanceUsecase.execute()) {
      case Ok(:final value):
        available = value.totalUnifiedSat;
      case Err(:final failure):
        return Err(failure);
    }
    if (sats.value > available.value) {
      return const Err(SilentAmountExceedsBalance());
    }
    return Ok(sats);
  }
}
