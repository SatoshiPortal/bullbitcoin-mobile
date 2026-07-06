import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_unlock/data/repositories/failed_unlock_attempts_repository_impl.dart';
import 'package:bb_mobile/features/app_unlock/domain/app_unlock_failure.dart';
import 'package:bb_mobile/features/app_unlock/domain/services/timeout_calculator.dart';
import 'package:bb_mobile/features/pin_code/domain/entities/unlock_attempt.dart';

class GetLatestUnlockAttemptUsecase {
  final FailedUnlockAttemptsRepository _failedUnlockAttemptsRepository;
  final TimeoutCalculator _timeoutCalculator;

  GetLatestUnlockAttemptUsecase({
    required this._failedUnlockAttemptsRepository,
    required this._timeoutCalculator,
  });

  Future<Result<UnlockAttempt, AppUnlockFailure>> execute() async {
    final int attempts;
    switch (await _failedUnlockAttemptsRepository.getFailedUnlockAttempts()) {
      case Ok(:final value):
        attempts = value;
      case Err(:final failure):
        return Err(failure);
    }

    final timeout = _timeoutCalculator.calculateTimeout(attempts);

    return Ok(
      UnlockAttempt(
        success: attempts == 0,
        timeout: timeout,
        failedAttempts: attempts,
      ),
    );
  }
}
