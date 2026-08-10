import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_unlock/data/repositories/failed_unlock_attempts_repository_impl.dart';
import 'package:bb_mobile/features/app_unlock/domain/app_unlock_failure.dart';
import 'package:bb_mobile/features/app_unlock/domain/services/timeout_calculator.dart';
import 'package:bb_mobile/features/app_unlock/domain/services/unlock_cooldown.dart';
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
  late UnlockCooldown unlockCooldown;
  late AttemptUnlockWithPinCodeUsecase usecase;

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    pinCodeRepository = MockPinCodeRepository();
    attemptsRepository = MockFailedUnlockAttemptsRepository();
    timeoutCalculator = MockTimeoutCalculator();
    unlockCooldown = UnlockCooldown();
    usecase = AttemptUnlockWithPinCodeUsecase(
      pinCodeRepository: pinCodeRepository,
      failedUnlockAttemptsRepository: attemptsRepository,
      timeoutCalculator: timeoutCalculator,
      unlockCooldown: unlockCooldown,
    );

    // No lockout in effect unless a test says otherwise.
    when(
      () => attemptsRepository.getLockedUntil(),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => attemptsRepository.setLockedUntil(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => attemptsRepository.getFailedUnlockAttempts(),
    ).thenAnswer((_) async => const Ok(0));
    when(() => timeoutCalculator.calculateTimeout(any())).thenReturn(0);
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

    test('clears any persisted lockout', () async {
      when(
        () => pinCodeRepository.verifyPinCode(any()),
      ).thenAnswer((_) async => const Ok(true));
      when(
        () => attemptsRepository.setFailedUnlockAttempts(0),
      ).thenAnswer((_) async => const Ok(null));

      await usecase.execute('1234');

      verify(() => attemptsRepository.setLockedUntil(null)).called(1);
    });
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

    test('persists a wall-clock lockout for the computed timeout', () async {
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

      final before = DateTime.now();
      await usecase.execute('0000');

      final captured = verify(
        () => attemptsRepository.setLockedUntil(captureAny()),
      ).captured;
      final lockedUntil = captured.single as DateTime;
      expect(
        lockedUntil.isAfter(before.add(const Duration(seconds: 29))),
        isTrue,
        reason:
            'the cooldown must be anchored to the wall clock so it '
            'survives an app restart',
      );
    });
  });

  group('active lockout', () {
    test(
      'audit reproducer: the PIN is never verified during a cooldown',
      () async {
        // Before the fix, execute() always verified the PIN first and only
        // computed a display timeout afterwards, so a 4-digit PIN (10,000
        // combinations) could be brute-forced with no enforced delay.
        when(() => attemptsRepository.getLockedUntil()).thenAnswer(
          (_) async => Ok(DateTime.now().add(const Duration(seconds: 30))),
        );
        when(
          () => attemptsRepository.getFailedUnlockAttempts(),
        ).thenAnswer((_) async => const Ok(4));
        when(() => timeoutCalculator.calculateTimeout(4)).thenReturn(30);

        final result = await usecase.execute('1234');

        verifyNever(() => pinCodeRepository.verifyPinCode(any()));
        final attempt = (result as Ok).value;
        expect(attempt.success, false);
        expect(attempt.failedAttempts, 4);
        expect(attempt.timeout, greaterThan(0));
        expect(attempt.timeout, lessThanOrEqualTo(30));
      },
    );

    test(
      'an expired wall-clock lockout is restored from the attempt count',
      () async {
        when(() => attemptsRepository.getLockedUntil()).thenAnswer(
          (_) async => Ok(DateTime.now().subtract(const Duration(seconds: 1))),
        );
        when(
          () => attemptsRepository.getFailedUnlockAttempts(),
        ).thenAnswer((_) async => const Ok(4));
        when(() => timeoutCalculator.calculateTimeout(4)).thenReturn(30);

        final result = await usecase.execute('1234');

        verifyNever(() => pinCodeRepository.verifyPinCode(any()));
        expect((result as Ok).value.timeout, 30);
      },
    );

    test('an elapsed monotonic cooldown lets the attempt through', () async {
      unlockCooldown.start(0);
      when(
        () => attemptsRepository.getFailedUnlockAttempts(),
      ).thenAnswer((_) async => const Ok(4));
      when(
        () => pinCodeRepository.verifyPinCode(any()),
      ).thenAnswer((_) async => const Ok(true));
      when(
        () => attemptsRepository.setFailedUnlockAttempts(0),
      ).thenAnswer((_) async => const Ok(null));

      final result = await usecase.execute('1234');

      verify(() => pinCodeRepository.verifyPinCode('1234')).called(1);
      expect((result as Ok).value.success, true);
    });
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

    test(
      'keeps the runtime cooldown when persisting its timestamp fails',
      () async {
        when(
          () => attemptsRepository.getFailedUnlockAttempts(),
        ).thenAnswer((_) async => const Ok(2));
        when(
          () => pinCodeRepository.verifyPinCode(any()),
        ).thenAnswer((_) async => const Ok(false));
        when(() => timeoutCalculator.calculateTimeout(2)).thenReturn(0);
        when(() => timeoutCalculator.calculateTimeout(3)).thenReturn(30);
        when(
          () => attemptsRepository.setFailedUnlockAttempts(3),
        ).thenAnswer((_) async => const Ok(null));
        when(() => attemptsRepository.setLockedUntil(any())).thenAnswer(
          (_) async => const Err(AppUnlockUnexpectedFailure('storage error')),
        );

        final failedPersistence = await usecase.execute('0000');
        final blockedRetry = await usecase.execute('0000');

        expect(failedPersistence, isA<Err>());
        expect((blockedRetry as Ok).value.timeout, 30);
        verify(() => pinCodeRepository.verifyPinCode('0000')).called(1);
      },
    );

    test(
      'returns Err(AppUnlockUnexpectedFailure) when getLockedUntil fails',
      () async {
        when(() => attemptsRepository.getLockedUntil()).thenAnswer(
          (_) async => const Err(AppUnlockUnexpectedFailure('storage error')),
        );

        final result = await usecase.execute('1234');

        expect(result, isA<Err>());
        expect((result as Err).failure, isA<AppUnlockUnexpectedFailure>());
        verifyNever(() => pinCodeRepository.verifyPinCode(any()));
      },
    );
  });
}
