import 'dart:io';

import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/app_unlock/domain/app_unlock_failure.dart';
import 'package:bb_mobile/features/app_unlock/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeSecureStoragePlatform storage;
  late CheckPinCodeExistsUsecase usecase;

  setUp(() {
    storage = FakeSecureStoragePlatform()..install();
    usecase = CheckPinCodeExistsUsecase(
      accessKeychain: Secrets(
        scratchDirectory: () async => Directory.systemTemp.path,
      ).accessKeychain,
    );
  });

  test('returns Ok(true) when pin code is set', () async {
    storage.entries['securityKey'] = 'synthetic';

    final result = await usecase.execute();

    expect(result, isA<Ok<bool, AppUnlockFailure>>());
    expect((result as Ok).value, true);
  });

  test('returns Ok(false) when pin code is not set', () async {
    final result = await usecase.execute();

    expect(result, isA<Ok<bool, AppUnlockFailure>>());
    expect((result as Ok).value, false);
  });

  test(
    'returns Err(AppUnlockPinCheckFailure) when repository fails — no raw leak',
    () async {
      storage.scripted.add(Exception('raw storage error'));

      final result = await usecase.execute();

      expect(result, isA<Err<bool, AppUnlockFailure>>());
      final failure = (result as Err).failure;
      expect(failure, isA<AppUnlockPinCheckFailure>());
      // Raw message must not surface as a new typed failure — it stays in logMessage only
      expect(failure, isNot(isA<AppUnlockUnexpectedFailure>()));
    },
  );

  test(
    'maps a keychain-locked repository failure without losing its type',
    () async {
      storage.locked = true;

      final result = await usecase.execute();

      expect(result, isA<Err<bool, AppUnlockFailure>>());
      expect((result as Err).failure, isA<AppUnlockKeychainLockedFailure>());
    },
  );
}
