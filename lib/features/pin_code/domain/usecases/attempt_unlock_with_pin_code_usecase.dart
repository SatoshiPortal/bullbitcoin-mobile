import 'package:bb_mobile/features/pin_code/domain/entities/unlock_attempt.dart';
import 'package:bb_mobile/features/pin_code/domain/repositories/pin_code_repository.dart';
import 'package:bb_mobile/features/pin_code/domain/services/timeout_calculator.dart';

class AttemptUnlockWithPinCodeUseCase {
  final PinCodeRepository _pinCodeRepository;
  final TimeoutCalculator _timeoutCalculator;

  AttemptUnlockWithPinCodeUseCase({
    required PinCodeRepository pinCodeRepository,
    required TimeoutCalculator timeoutCalculator,
  })  : _pinCodeRepository = pinCodeRepository,
        _timeoutCalculator = timeoutCalculator;

  Future<UnlockAttempt> execute(String pinCode) async {
    final isCorrectPinCode = await _pinCodeRepository.verifyPinCode(pinCode);
    int timeout = 0;
    int attempts = 0;

    if (!isCorrectPinCode) {
      // Get the current number of failed attempts
      final currentNrOfAttempts =
          await _pinCodeRepository.getFailedUnlockAttempts();

      // Increment the failed attempts
      attempts = currentNrOfAttempts + 1;

      // Calculate the timeout based on the number of attempts
      timeout = _timeoutCalculator.calculateTimeout(attempts);
    }

    // Save the new number of failed attempts
    await _pinCodeRepository.setFailedUnlockAttempts(attempts);

    return UnlockAttempt(
      success: isCorrectPinCode,
      timeout: timeout,
      failedAttempts: attempts,
    );
  }
}
