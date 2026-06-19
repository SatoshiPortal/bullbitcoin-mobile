import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_unlock/data/repositories/failed_unlock_attempts_repository_impl.dart';
import 'package:bb_mobile/features/app_unlock/domain/app_unlock_failure.dart';
import 'package:bb_mobile/features/app_unlock/domain/services/timeout_calculator.dart';
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
    );
  });

  test('returns Ok with success=true when no prior failed attempts', () async {
    when(() => attemptsRepository.getFailedUnlockAttempts())
        .thenAnswer((_) async => const Ok(0));
    when(() => timeoutCalculator.calculateTimeout(0)).thenReturn(0);

    final result = await usecase.execute();

    expect(result, isA<Ok>());
    final attempt = (result as Ok).value;
    expect(attempt.success, true);
    expect(attempt.failedAttempts, 0);
    expect(attempt.timeout, 0);
  });

  test('returns Ok with correct attempts and timeout when prior failures exist',
      () async {
    when(() => attemptsRepository.getFailedUnlockAttempts())
        .thenAnswer((_) async => const Ok(3));
    when(() => timeoutCalculator.calculateTimeout(3)).thenReturn(60);

    final result = await usecase.execute();

    expect(result, isA<Ok>());
    final attempt = (result as Ok).value;
    expect(attempt.success, false);
    expect(attempt.failedAttempts, 3);
    expect(attempt.timeout, 60);
  });

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
