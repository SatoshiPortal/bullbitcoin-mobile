import 'dart:io';

import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:access/src/data/repositories/failed_unlock_attempts_repository_impl.dart';
import 'package:access/src/domain/access_failure.dart';
import 'package:access/src/domain/entities/unlock_attempt.dart';
import 'package:access/src/domain/services/timeout_calculator.dart';
import 'package:access/src/domain/services/unlock_cooldown.dart';
import 'package:access/src/domain/usecases/attempt_unlock_with_pin_code_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class RecordingStorage extends FakeSecureStoragePlatform {
  final keysRead = <String>[];
  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) {
    keysRead.add(key);
    return super.read(key: key, options: options);
  }
}

class MockFailedUnlockAttemptsRepository extends Mock
    implements FailedUnlockAttemptsRepository {}

class MockTimeoutCalculator extends Mock implements TimeoutCalculator {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RecordingStorage storage;
  late MockFailedUnlockAttemptsRepository attemptsRepository;
  late MockTimeoutCalculator timeoutCalculator;
  late UnlockCooldown unlockCooldown;
  late AttemptUnlockWithPinCodeUsecase usecase;

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    storage = RecordingStorage()..install();
    attemptsRepository = MockFailedUnlockAttemptsRepository();
    timeoutCalculator = MockTimeoutCalculator();
    unlockCooldown = UnlockCooldown();
    usecase = AttemptUnlockWithPinCodeUsecase(
      accessKeychain: Secrets(
        scratchDirectory: () async => Directory.systemTemp.path,
      ).accessKeychain,
      failedUnlockAttemptsRepository: attemptsRepository,
      timeoutCalculator: timeoutCalculator,
      unlockCooldown: unlockCooldown,
    );

    // No lockout in effect unless a test says otherwise.
    when(() => attemptsRepository.getLockedUntil())
        .thenAnswer((_) async => const Ok(null));
    when(() => attemptsRepository.setLockedUntil(any()))
        .thenAnswer((_) async => const Ok(null));
    when(() => attemptsRepository.getFailedUnlockAttempts())
        .thenAnswer((_) async => const Ok(0));
    when(() => timeoutCalculator.calculateTimeout(any())).thenReturn(0);
  });

  group('correct PIN', () {
    test(
      'returns Ok(UnlockAttempt(success: true)) and resets counter',
      () async {
        storage.entries['securityKey'] = '1234';
        when(() => attemptsRepository.setFailedUnlockAttempts(0))
            .thenAnswer((_) async => const Ok(null));

        final result = await usecase.execute('1234');

        expect(result, isA<Ok>());
        final attempt = (result as Ok).value;
        expect(attempt.success, true);
        expect(attempt.failedAttempts, 0);
      },
    );

    test('clears any persisted lockout', () async {
      storage.entries['securityKey'] = '1234';
      when(() => attemptsRepository.setFailedUnlockAttempts(0))
          .thenAnswer((_) async => const Ok(null));

      await usecase.execute('1234');

      verify(() => attemptsRepository.setLockedUntil(null)).called(1);
    });
  });

  group('PIN access failures', () {
    test('an absent PIN fails without recording a wrong attempt', () async {
      final result = await usecase.execute('0000');

      expect(
        result,
        isA<Err<UnlockAttempt, AccessFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<AccessPinVerifyFailure>(),
        ),
      );
      expect(storage.keysRead, ['securityKey']);
      expect(storage.entries, isEmpty);
      verifyNever(() => attemptsRepository.setFailedUnlockAttempts(any()));
      verifyNever(() => attemptsRepository.setLockedUntil(any()));
    });

    test(
      'a locked PIN read preserves its failure and changes nothing',
      () async {
        storage.entries['securityKey'] = '1234';
        storage.locked = true;
        final before = Map<String, String>.of(storage.entries);

        final result = await usecase.execute('0000');

        expect(
          result,
          isA<Err<UnlockAttempt, AccessFailure>>().having(
            (result) => result.failure,
            'failure',
            isA<AccessPinVerifyFailure>().having(
              (failure) => failure.logMessage,
              'message',
              'Keychain locked',
            ),
          ),
        );
        expect(storage.keysRead, ['securityKey']);
        expect(storage.entries, before);
        verifyNever(() => attemptsRepository.setFailedUnlockAttempts(any()));
        verifyNever(() => attemptsRepository.setLockedUntil(any()));
      },
    );
  });

  group('wrong PIN', () {
    test(
      'increments counter and returns Ok(UnlockAttempt(success: false))',
      () async {
        storage.entries['securityKey'] = '1234';
        when(() => attemptsRepository.getFailedUnlockAttempts())
            .thenAnswer((_) async => const Ok(2));
        when(() => timeoutCalculator.calculateTimeout(3)).thenReturn(30);
        when(() => attemptsRepository.setFailedUnlockAttempts(3))
            .thenAnswer((_) async => const Ok(null));

        final result = await usecase.execute('0000');

        expect(result, isA<Ok>());
        final attempt = (result as Ok).value;
        expect(attempt.success, false);
        expect(attempt.failedAttempts, 3);
        expect(attempt.timeout, 30);
      },
    );

    test('persists a wall-clock lockout for the computed timeout', () async {
      storage.entries['securityKey'] = '1234';
      when(() => attemptsRepository.getFailedUnlockAttempts())
          .thenAnswer((_) async => const Ok(2));
      when(() => timeoutCalculator.calculateTimeout(3)).thenReturn(30);
      when(() => attemptsRepository.setFailedUnlockAttempts(3))
          .thenAnswer((_) async => const Ok(null));

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
        when(() => attemptsRepository.getFailedUnlockAttempts())
            .thenAnswer((_) async => const Ok(4));
        when(() => timeoutCalculator.calculateTimeout(4)).thenReturn(30);

        final result = await usecase.execute('1234');

        expect(storage.keysRead, isNot(contains('securityKey')));
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
        when(() => attemptsRepository.getFailedUnlockAttempts())
            .thenAnswer((_) async => const Ok(4));
        when(() => timeoutCalculator.calculateTimeout(4)).thenReturn(30);

        final result = await usecase.execute('1234');

        expect(storage.keysRead, isNot(contains('securityKey')));
        expect((result as Ok).value.timeout, 30);
      },
    );

    test('an elapsed monotonic cooldown lets the attempt through', () async {
      unlockCooldown.start(0);
      when(() => attemptsRepository.getFailedUnlockAttempts())
          .thenAnswer((_) async => const Ok(4));
      storage.entries['securityKey'] = '1234';
      when(() => attemptsRepository.setFailedUnlockAttempts(0))
          .thenAnswer((_) async => const Ok(null));

      final result = await usecase.execute('1234');

      expect(storage.keysRead.where((key) => key == 'securityKey').length, 1);
      expect((result as Ok).value.success, true);
    });
  });

  group('sanitized failures — no raw leak', () {
    test(
      'returns Err(AccessPinVerifyFailure) when verifyPinCode fails',
      () async {
        storage.scripted.add(Exception('raw keychain error'));

        final result = await usecase.execute('1234');

        expect(result, isA<Err>());
        expect((result as Err).failure, isA<AccessPinVerifyFailure>());
      },
    );

    test('returns Err(AccessUnlockUnexpectedFailure) when getFailedUnlockAttempts fails', () async {
      storage.entries['securityKey'] = '1234';
      when(() => attemptsRepository.getFailedUnlockAttempts()).thenAnswer(
        (_) async => const Err(AccessUnlockUnexpectedFailure('storage error')),
      );

      final result = await usecase.execute('0000');

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<AccessUnlockUnexpectedFailure>());
    });

    test('returns Err(AccessUnlockUnexpectedFailure) when setFailedUnlockAttempts fails', () async {
      storage.entries['securityKey'] = '1234';
      when(() => attemptsRepository.setFailedUnlockAttempts(0)).thenAnswer(
        (_) async => const Err(AccessUnlockUnexpectedFailure('storage error')),
      );

      final result = await usecase.execute('1234');

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<AccessUnlockUnexpectedFailure>());
    });

    test(
      'keeps the runtime cooldown when persisting its timestamp fails',
      () async {
        when(() => attemptsRepository.getFailedUnlockAttempts())
            .thenAnswer((_) async => const Ok(2));
        storage.entries['securityKey'] = '1234';
        when(() => timeoutCalculator.calculateTimeout(2)).thenReturn(0);
        when(() => timeoutCalculator.calculateTimeout(3)).thenReturn(30);
        when(() => attemptsRepository.setFailedUnlockAttempts(3))
            .thenAnswer((_) async => const Ok(null));
        when(() => attemptsRepository.setLockedUntil(any())).thenAnswer(
          (_) async =>
              const Err(AccessUnlockUnexpectedFailure('storage error')),
        );

        final failedPersistence = await usecase.execute('0000');
        final blockedRetry = await usecase.execute('0000');

        expect(failedPersistence, isA<Err>());
        expect((blockedRetry as Ok).value.timeout, 30);
        expect(storage.keysRead.where((key) => key == 'securityKey').length, 1);
      },
    );

    test(
      'returns Err(AccessUnlockUnexpectedFailure) when getLockedUntil fails',
      () async {
        when(() => attemptsRepository.getLockedUntil()).thenAnswer(
          (_) async =>
              const Err(AccessUnlockUnexpectedFailure('storage error')),
        );

        final result = await usecase.execute('1234');

        expect(result, isA<Err>());
        expect((result as Err).failure, isA<AccessUnlockUnexpectedFailure>());
        expect(storage.keysRead, isNot(contains('securityKey')));
      },
    );
  });
}
