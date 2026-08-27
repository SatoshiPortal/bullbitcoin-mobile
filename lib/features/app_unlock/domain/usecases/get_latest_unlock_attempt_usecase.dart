import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_unlock/data/repositories/failed_unlock_attempts_repository_impl.dart';
import 'package:bb_mobile/features/app_unlock/domain/app_unlock_failure.dart';
import 'package:bb_mobile/features/app_unlock/domain/services/timeout_calculator.dart';
import 'package:bb_mobile/features/app_unlock/domain/services/unlock_cooldown.dart';
import 'package:bb_mobile/features/pin_code/domain/entities/unlock_attempt.dart';

class GetLatestUnlockAttemptUsecase {
  final FailedUnlockAttemptsRepository _failedUnlockAttemptsRepository;
  final TimeoutCalculator _timeoutCalculator;
  final UnlockCooldown _unlockCooldown;

  GetLatestUnlockAttemptUsecase({
    required this._failedUnlockAttemptsRepository,
    required this._timeoutCalculator,
    required this._unlockCooldown,
  });

  Future<Result<UnlockAttempt, AppUnlockFailure>> execute() async {
    final int attempts;
    switch (await _failedUnlockAttemptsRepository.getFailedUnlockAttempts()) {
      case Ok(:final value):
        attempts = value;
      case Err(:final failure):
        return Err(failure);
    }

    // The remaining cooldown comes from the persisted wall-clock timestamp,
    // not from a fresh calculation: recomputing it from the attempt count
    // would restart a full timeout on every app restart, and (before the
    // lockout was enforced) suggested the countdown was the control.
    final DateTime? lockedUntil;
    switch (await _failedUnlockAttemptsRepository.getLockedUntil()) {
      case Ok(:final value):
        lockedUntil = value;
      case Err(:final failure):
        return Err(failure);
    }

    _unlockCooldown.restore(
      fallbackSeconds: _timeoutCalculator.calculateTimeout(attempts),
      lockedUntil: lockedUntil,
      now: DateTime.now(),
    );
    final remaining = _unlockCooldown.remainingSeconds;

    return Ok(
      UnlockAttempt(
        success: attempts == 0,
        timeout: remaining,
        failedAttempts: attempts,
      ),
    );
  }
}
