import 'dart:io';

import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/pin_code/domain/pin_code_failure.dart';
import 'package:bb_mobile/features/pin_code/domain/usecases/is_pin_code_set_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('preserves a keychain-locked failure', () async {
    FakeSecureStoragePlatform(locked: true).install();
    final usecase = IsPinCodeSetUsecase(
      accessKeychain: Secrets(
        scratchDirectory: () async => Directory.systemTemp.path,
      ).accessKeychain,
    );
    final result = await usecase.execute();
    expect(result, isA<Err<bool, PinCodeFailure>>());
    expect((result as Err).failure, isA<PinCodeKeychainLockedFailure>());
  });
}
