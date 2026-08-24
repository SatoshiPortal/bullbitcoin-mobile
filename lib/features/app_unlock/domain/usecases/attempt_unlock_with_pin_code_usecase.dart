import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_unlock/data/repositories/failed_unlock_attempts_repository_impl.dart';
import 'package:bb_mobile/features/app_unlock/domain/app_unlock_failure.dart';
import 'package:bb_mobile/features/app_unlock/domain/services/timeout_calculator.dart';
import 'package:bb_mobile/features/app_unlock/domain/services/unlock_cooldown.dart';
import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';
import 'package:bb_mobile/features/pin_code/domain/entities/unlock_attempt.dart';

class AttemptUnlockWithPinCodeUsecase {
  final PinCodeRepository _pinCodeRepository;
  final FailedUnlockAttemptsRepository _failedUnlockAttemptsRepository;
  final TimeoutCalculator _timeoutCalculator;
  final UnlockCooldown _unlockCooldown;

  AttemptUnlockWithPinCodeUsecase({
    required this._pinCodeRepository,
    required this._failedUnlockAttemptsRepository,
    required this._timeoutCalculator,
    required this._unlockCooldown,
  });

  Future<Result<UnlockAttempt, AppUnlockFailure>> execute(
    String pinCode,
  ) async {
    // The lockout is enforced here, at the domain boundary — never in the
    // UI alone. While a cooldown is running the PIN is not even compared,
    // so a brute-forcer gets neither a signal nor a faster attempt rate,
    // whatever entry point drives the attempts.
    final DateTime? lockedUntil;
    switch (await _failedUnlockAttemptsRepository.getLockedUntil()) {
      case Ok(:final value):
        lockedUntil = value;
      case Err(:final failure):
        return Err(failure);
    }

    final int currentAttempts;
    switch (await _failedUnlockAttemptsRepository.getFailedUnlockAttempts()) {
      case Ok(:final value):
        currentAttempts = value;
      case Err(:final failure):
        return Err(failure);
    }
    _unlockCooldown.restore(
      fallbackSeconds: _timeoutCalculator.calculateTimeout(currentAttempts),
      lockedUntil: lockedUntil,
      now: DateTime.now(),
    );
    final remaining = _unlockCooldown.remainingSeconds;
    if (remaining > 0) {
      return Ok(
        UnlockAttempt(
          success: false,
          timeout: remaining,
          failedAttempts: currentAttempts,
        ),
      );
    }

    final bool isCorrectPinCode;
    switch (await _pinCodeRepository.verifyPinCode(pinCode)) {
      case Ok(:final value):
        isCorrectPinCode = value;
      case Err(:final failure):
        return Err(AppUnlockPinVerifyFailure(failure.logMessage));
    }

    int timeout = 0;
    int attempts = 0;

    if (!isCorrectPinCode) {
      attempts = currentAttempts + 1;

      // Calculate the timeout based on the number of attempts
      timeout = _timeoutCalculator.calculateTimeout(attempts);
      // Keep the in-process gate fail-closed even if persistence fails.
      _unlockCooldown.start(timeout);
    }
    // Save the new number of failed attempts
    final saveResult = await _failedUnlockAttemptsRepository
        .setFailedUnlockAttempts(attempts);
    if (saveResult case Err(:final failure)) return Err(failure);

    // Anchor the cooldown to the wall clock so it survives an app restart;
    // a successful unlock clears it.
    final lockoutResult = await _failedUnlockAttemptsRepository.setLockedUntil(
      timeout > 0 ? DateTime.now().add(Duration(seconds: timeout)) : null,
    );
    if (lockoutResult case Err(:final failure)) return Err(failure);
    if (isCorrectPinCode) {
      _unlockCooldown.clear();
    }

    return Ok(
      UnlockAttempt(
        success: isCorrectPinCode,
        timeout: timeout,
        failedAttempts: attempts,
      ),
    );
  }
}
