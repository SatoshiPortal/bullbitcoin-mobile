import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_unlock/data/repositories/failed_unlock_attempts_repository_impl.dart';
import 'package:bb_mobile/features/app_unlock/domain/app_unlock_failure.dart';
import 'package:bb_mobile/features/app_unlock/domain/services/timeout_calculator.dart';
import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';
import 'package:bb_mobile/features/pin_code/domain/entities/unlock_attempt.dart';

class AttemptUnlockWithPinCodeUsecase {
  final PinCodeRepository _pinCodeRepository;
  final FailedUnlockAttemptsRepository _failedUnlockAttemptsRepository;
  final TimeoutCalculator _timeoutCalculator;

  AttemptUnlockWithPinCodeUsecase({
    required this._pinCodeRepository,
    required this._failedUnlockAttemptsRepository,
    required this._timeoutCalculator,
  });

  Future<Result<UnlockAttempt, AppUnlockFailure>> execute(
    String pinCode,
  ) async {
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
      final int currentNrOfAttempts;
      // Get the current number of failed attempts
      switch (await _failedUnlockAttemptsRepository.getFailedUnlockAttempts()) {
        case Ok(:final value):
          currentNrOfAttempts = value;
        case Err(:final failure):
          return Err(failure);
      }
      attempts = currentNrOfAttempts + 1;

      // Calculate the timeout based on the number of attempts
      timeout = _timeoutCalculator.calculateTimeout(attempts);
    }
    // Save the new number of failed attempts
    final saveResult = await _failedUnlockAttemptsRepository
        .setFailedUnlockAttempts(attempts);
    if (saveResult case Err(:final failure)) return Err(failure);

    return Ok(
      UnlockAttempt(
        success: isCorrectPinCode,
        timeout: timeout,
        failedAttempts: attempts,
      ),
    );
  }
}
