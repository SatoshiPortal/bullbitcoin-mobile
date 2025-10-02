import 'package:bb_mobile/features/app_unlock/data/repositories/failed_unlock_attempts_repository_impl.dart';
import 'package:bb_mobile/features/app_unlock/domain/services/timeout_calculator.dart';
import 'package:bb_mobile/features/pin_code/domain/entities/unlock_attempt.dart';

class GetLatestUnlockAttemptUsecase {
  final FailedUnlockAttemptsRepository _failedUnlockAttemptsRepository;
  final TimeoutCalculator _timeoutCalculator;

  GetLatestUnlockAttemptUsecase({
    required FailedUnlockAttemptsRepository failedUnlockAttemptsRepository,
    required TimeoutCalculator timeoutCalculator,
  }) : _failedUnlockAttemptsRepository = failedUnlockAttemptsRepository,
       _timeoutCalculator = timeoutCalculator;

  Future<UnlockAttempt> execute() async {
    final attempts =
        await _failedUnlockAttemptsRepository.getFailedUnlockAttempts();

    final timeout = _timeoutCalculator.calculateTimeout(attempts);

    return UnlockAttempt(
      success: attempts == 0,
      timeout: timeout,
      failedAttempts: attempts,
    );
  }
}
