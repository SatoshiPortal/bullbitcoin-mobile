import 'package:bb_mobile/features/app_unlock/data/repositories/failed_unlock_attempts_repository_impl.dart';
import 'package:bb_mobile/features/app_unlock/domain/services/timeout_calculator.dart';
import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';
import 'package:bb_mobile/features/pin_code/domain/entities/unlock_attempt.dart';

class AttemptUnlockWithPinCodeUsecase {
  final PinCodeRepository _pinCodeRepository;
  final FailedUnlockAttemptsRepository _failedUnlockAttemptsRepository;
  final TimeoutCalculator _timeoutCalculator;

  AttemptUnlockWithPinCodeUsecase({
    required PinCodeRepository pinCodeRepository,
    required FailedUnlockAttemptsRepository failedUnlockAttemptsRepository,
    required TimeoutCalculator timeoutCalculator,
  }) : _pinCodeRepository = pinCodeRepository,
       _failedUnlockAttemptsRepository = failedUnlockAttemptsRepository,
       _timeoutCalculator = timeoutCalculator;

  Future<UnlockAttempt> execute(String pinCode) async {
    final isCorrectPinCode = await _pinCodeRepository.verifyPinCode(pinCode);
    int timeout = 0;
    int attempts = 0;

    if (!isCorrectPinCode) {
      // Get the current number of failed attempts
      final currentNrOfAttempts =
          await _failedUnlockAttemptsRepository.getFailedUnlockAttempts();

      // Increment the failed attempts
      attempts = currentNrOfAttempts + 1;

      // Calculate the timeout based on the number of attempts
      timeout = _timeoutCalculator.calculateTimeout(attempts);
    }

    // Save the new number of failed attempts
    await _failedUnlockAttemptsRepository.setFailedUnlockAttempts(attempts);

    return UnlockAttempt(
      success: isCorrectPinCode,
      timeout: timeout,
      failedAttempts: attempts,
    );
  }
}
