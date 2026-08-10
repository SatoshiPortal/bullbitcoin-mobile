import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_unlock/data/repositories/failed_unlock_attempts_repository_impl.dart';
import 'package:bb_mobile/features/app_unlock/domain/app_unlock_failure.dart';
import 'package:bb_mobile/features/app_unlock/domain/services/timeout_calculator.dart';
import 'package:bb_mobile/features/app_unlock/domain/services/unlock_cooldown.dart';
import 'package:bb_mobile/features/app_unlock/domain/usecases/get_latest_unlock_attempt_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFailedUnlockAttemptsRepository extends Mock
    implements FailedUnlockAttemptsRepository {}

class MockTimeoutCalculator extends Mock implements TimeoutCalculator {}

void main() {
  late MockFailedUnlockAttemptsRepository attemptsRepository;
  late MockTimeoutCalculator timeoutCalculator;
  late GetLatestUnlockAttemptUsecase usecase;

  setUp(() {
    attemptsRepository = MockFailedUnlockAttemptsRepository();
    timeoutCalculator = MockTimeoutCalculator();
    usecase = GetLatestUnlockAttemptUsecase(
      failedUnlockAttemptsRepository: attemptsRepository,
      timeoutCalculator: timeoutCalculator,
      unlockCooldown: UnlockCooldown(),
    );

    when(
      () => attemptsRepository.getLockedUntil(),
    ).thenAnswer((_) async => const Ok(null));
    when(() => timeoutCalculator.calculateTimeout(any())).thenReturn(0);
  });

  test('returns Ok with success=true when no prior failed attempts', () async {
    when(
      () => attemptsRepository.getFailedUnlockAttempts(),
    ).thenAnswer((_) async => const Ok(0));

    final result = await usecase.execute();

    expect(result, isA<Ok>());
    final attempt = (result as Ok).value;
    expect(attempt.success, true);
    expect(attempt.failedAttempts, 0);
    expect(attempt.timeout, 0);
  });

  test(
    'restores a bounded remaining cooldown from the persisted timestamp',
    () async {
      when(
        () => attemptsRepository.getFailedUnlockAttempts(),
      ).thenAnswer((_) async => const Ok(4));
      when(() => attemptsRepository.getLockedUntil()).thenAnswer(
        (_) async => Ok(DateTime.now().add(const Duration(seconds: 22))),
      );
      when(() => timeoutCalculator.calculateTimeout(4)).thenReturn(30);

      final result = await usecase.execute();

      final attempt = (result as Ok).value;
      expect(attempt.success, false);
      expect(attempt.failedAttempts, 4);
      expect(attempt.timeout, greaterThan(20));
      expect(attempt.timeout, lessThanOrEqualTo(22));
    },
  );

  test(
    'an expired wall-clock lockout falls back to the calculated timeout',
    () async {
      when(
        () => attemptsRepository.getFailedUnlockAttempts(),
      ).thenAnswer((_) async => const Ok(4));
      when(() => attemptsRepository.getLockedUntil()).thenAnswer(
        (_) async => Ok(DateTime.now().subtract(const Duration(minutes: 1))),
      );
      when(() => timeoutCalculator.calculateTimeout(4)).thenReturn(30);

      final result = await usecase.execute();

      expect((result as Ok).value.timeout, 30);
    },
  );

  test(
    'returns Err(AppUnlockUnexpectedFailure) when repository fails — no raw leak',
    () async {
      when(() => attemptsRepository.getFailedUnlockAttempts()).thenAnswer(
        (_) async => const Err(AppUnlockUnexpectedFailure('storage error')),
      );

      final result = await usecase.execute();

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<AppUnlockUnexpectedFailure>());
    },
  );
}
