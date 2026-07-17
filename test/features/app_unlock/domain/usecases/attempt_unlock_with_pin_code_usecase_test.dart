import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_unlock/data/repositories/failed_unlock_attempts_repository_impl.dart';
import 'package:bb_mobile/features/app_unlock/domain/app_unlock_failure.dart';
import 'package:bb_mobile/features/app_unlock/domain/services/timeout_calculator.dart';
import 'package:bb_mobile/features/app_unlock/domain/usecases/attempt_unlock_with_pin_code_usecase.dart';
import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';
import 'package:bb_mobile/features/pin_code/domain/pin_code_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPinCodeRepository extends Mock implements PinCodeRepository {}

class MockFailedUnlockAttemptsRepository extends Mock
    implements FailedUnlockAttemptsRepository {}

class MockTimeoutCalculator extends Mock implements TimeoutCalculator {}

void main() {
  late MockPinCodeRepository pinCodeRepository;
  late MockFailedUnlockAttemptsRepository attemptsRepository;
  late MockTimeoutCalculator timeoutCalculator;
  late AttemptUnlockWithPinCodeUsecase usecase;

  setUp(() {
    pinCodeRepository = MockPinCodeRepository();
    attemptsRepository = MockFailedUnlockAttemptsRepository();
    timeoutCalculator = MockTimeoutCalculator();
    usecase = AttemptUnlockWithPinCodeUsecase(
      pinCodeRepository: pinCodeRepository,
      failedUnlockAttemptsRepository: attemptsRepository,
      timeoutCalculator: timeoutCalculator,
    );
  });

  group('correct PIN', () {
    test(
      'returns Ok(UnlockAttempt(success: true)) and resets counter',
      () async {
        when(
          () => pinCodeRepository.verifyPinCode(any()),
        ).thenAnswer((_) async => const Ok(true));
        when(
          () => attemptsRepository.setFailedUnlockAttempts(0),
        ).thenAnswer((_) async => const Ok(null));

        final result = await usecase.execute('1234');

        expect(result, isA<Ok>());
        final attempt = (result as Ok).value;
        expect(attempt.success, true);
        expect(attempt.failedAttempts, 0);
      },
    );
  });

  group('wrong PIN', () {
    test(
      'increments counter and returns Ok(UnlockAttempt(success: false))',
      () async {
        when(
          () => pinCodeRepository.verifyPinCode(any()),
        ).thenAnswer((_) async => const Ok(false));
        when(
          () => attemptsRepository.getFailedUnlockAttempts(),
        ).thenAnswer((_) async => const Ok(2));
        when(() => timeoutCalculator.calculateTimeout(3)).thenReturn(30);
        when(
          () => attemptsRepository.setFailedUnlockAttempts(3),
        ).thenAnswer((_) async => const Ok(null));

        final result = await usecase.execute('0000');

        expect(result, isA<Ok>());
        final attempt = (result as Ok).value;
        expect(attempt.success, false);
        expect(attempt.failedAttempts, 3);
        expect(attempt.timeout, 30);
      },
    );
  });

  group('sanitized failures — no raw leak', () {
    test(
      'returns Err(AppUnlockPinVerifyFailure) when verifyPinCode fails',
      () async {
        when(() => pinCodeRepository.verifyPinCode(any())).thenAnswer(
          (_) async =>
              const Err(PinCodeUnexpectedFailure('raw keychain error')),
        );

        final result = await usecase.execute('1234');

        expect(result, isA<Err>());
        expect((result as Err).failure, isA<AppUnlockPinVerifyFailure>());
      },
    );

    test(
      'returns Err(AppUnlockUnexpectedFailure) when getFailedUnlockAttempts fails',
      () async {
        when(
          () => pinCodeRepository.verifyPinCode(any()),
        ).thenAnswer((_) async => const Ok(false));
        when(() => attemptsRepository.getFailedUnlockAttempts()).thenAnswer(
          (_) async => const Err(AppUnlockUnexpectedFailure('storage error')),
        );

        final result = await usecase.execute('0000');

        expect(result, isA<Err>());
        expect((result as Err).failure, isA<AppUnlockUnexpectedFailure>());
      },
    );

    test(
      'returns Err(AppUnlockUnexpectedFailure) when setFailedUnlockAttempts fails',
      () async {
        when(
          () => pinCodeRepository.verifyPinCode(any()),
        ).thenAnswer((_) async => const Ok(true));
        when(() => attemptsRepository.setFailedUnlockAttempts(0)).thenAnswer(
          (_) async => const Err(AppUnlockUnexpectedFailure('storage error')),
        );

        final result = await usecase.execute('1234');

        expect(result, isA<Err>());
        expect((result as Err).failure, isA<AppUnlockUnexpectedFailure>());
      },
    );
  });
}
