import 'dart:io';

import 'package:bb_mobile/features/app_unlock/data/repositories/failed_unlock_attempts_repository_impl.dart';
import 'package:bb_mobile/features/app_unlock/domain/app_unlock_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeSecureStoragePlatform storage;
  late FailedUnlockAttemptsRepository repository;
  setUp(() {
    storage = FakeSecureStoragePlatform()..install();
    repository = FailedUnlockAttemptsRepository(
      Secrets(scratchDirectory: () async => Directory.systemTemp.path)
          .accessKeychain,
    );
  });

  test('reads attempts as an integer and defaults missing or invalid values to zero', () async {
    storage.entries['failedUnlockAttemptsKey'] = '3';
    expect((await repository.getFailedUnlockAttempts() as Ok).value, 3);
    storage.entries.remove('failedUnlockAttemptsKey');
    expect((await repository.getFailedUnlockAttempts() as Ok).value, 0);
    storage.entries['failedUnlockAttemptsKey'] = 'invalid';
    expect((await repository.getFailedUnlockAttempts() as Ok).value, 0);
  });
  test('writes attempts to the legacy key', () async {
    expect(
      await repository.setFailedUnlockAttempts(3),
      isA<Ok<void, AppUnlockFailure>>(),
    );
    expect(storage.entries['failedUnlockAttemptsKey'], '3');
  });
  test('maps read and write errors to app unlock failures', () async {
    storage.scripted.add(Exception('storage error'));
    expect(
      await repository.getFailedUnlockAttempts(),
      isA<Err<int, AppUnlockFailure>>().having(
        (e) => e.failure,
        'failure',
        isA<AppUnlockUnexpectedFailure>(),
      ),
    );
    storage.scriptedWrites.add(Exception('storage error'));
    expect(
      await repository.setFailedUnlockAttempts(3),
      isA<Err<void, AppUnlockFailure>>().having(
        (e) => e.failure,
        'failure',
        isA<AppUnlockUnexpectedFailure>(),
      ),
    );
  });
  test(
    'persists, reads and clears the lockout timestamp at its legacy key',
    () async {
      final time = DateTime.fromMillisecondsSinceEpoch(1786000000000);
      expect(
        await repository.setLockedUntil(time),
        isA<Ok<void, AppUnlockFailure>>(),
      );
      expect(storage.entries['unlockLockedUntilKey'], '1786000000000');
      expect((await repository.getLockedUntil() as Ok).value, time);
      expect(
        await repository.setLockedUntil(null),
        isA<Ok<void, AppUnlockFailure>>(),
      );
      expect(storage.entries.containsKey('unlockLockedUntilKey'), isFalse);
      expect((await repository.getLockedUntil() as Ok).value, isNull);
    },
  );
  test('maps a lockout read error to app unlock failure', () async {
    storage.scripted.add(Exception('storage error'));
    expect(
      await repository.getLockedUntil(),
      isA<Err<DateTime?, AppUnlockFailure>>().having(
        (e) => e.failure,
        'failure',
        isA<AppUnlockUnexpectedFailure>(),
      ),
    );
  });
}
