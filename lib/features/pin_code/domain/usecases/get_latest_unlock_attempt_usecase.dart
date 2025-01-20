import 'package:bb_mobile/features/pin_code/domain/entities/unlock_attempt.dart';
import 'package:bb_mobile/features/pin_code/domain/repositories/pin_code_repository.dart';
import 'package:bb_mobile/features/pin_code/domain/services/timeout_calculator.dart';

class GetLatestUnlockAttemptUseCase {
  final PinCodeRepository _pinCodeRepository;
  final TimeoutCalculator _timeoutCalculator;

  GetLatestUnlockAttemptUseCase({
    required PinCodeRepository pinCodeRepository,
    required TimeoutCalculator timeoutCalculator,
  })  : _pinCodeRepository = pinCodeRepository,
        _timeoutCalculator = timeoutCalculator;

  Future<UnlockAttempt> execute() async {
    final attempts = await _pinCodeRepository.getFailedUnlockAttempts();

    final timeout = _timeoutCalculator.calculateTimeout(attempts);

    return UnlockAttempt(
      success: attempts == 0,
      timeout: timeout,
      failedAttempts: attempts,
    );
  }
}
