import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';
import 'package:bb_mobile/features/pin_code/domain/pin_code_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

void main() {
  late FakeSecureStoragePlatform storage;
  late PinCodeRepository repository;

  setUp(() {
    storage = FakeSecureStoragePlatform().install();
    repository = PinCodeRepository(
      Secrets(
        scratchDirectory: () async => '/tmp/pr2938-pin-test',
      ).appUnlockCredential,
    );
  });

  test('maps a locked keychain to PinCodeKeychainLockedFailure', () async {
    storage.locked = true;
    final result = await repository.isPinCodeSet();
    expect(result, isA<Err<bool, PinCodeFailure>>());
    expect((result as Err).failure, isA<PinCodeKeychainLockedFailure>());
    expect(
      (await repository.verifyPinCode('123456') as Err).failure,
      isA<PinCodeKeychainLockedFailure>(),
    );
  });

  test('preserves existing PIN and maps missing PIN after deletion', () async {
    storage.entries['securityKey'] = '123456';
    expect((await repository.isPinCodeSet() as Ok).value, isTrue);
    expect((await repository.verifyPinCode('123456') as Ok).value, isTrue);
    expect((await repository.verifyPinCode('654321') as Ok).value, isFalse);
    expect(await repository.deletePinCode(), isA<Ok>());
    expect((await repository.isPinCodeSet() as Ok).value, isFalse);
    expect(
      (await repository.verifyPinCode('123456') as Err).failure,
      isA<PinCodeNotSetFailure>(),
    );
  });

  test('maps refused mutations without deleting the stored PIN', () async {
    storage.entries['securityKey'] = '123456';
    storage.writesFail = true;
    expect(
      (await repository.setPinCode('654321') as Err).failure,
      isA<PinCodeSaveFailure>(),
    );
    expect(
      (await repository.deletePinCode() as Err).failure,
      isA<PinCodeDeleteFailure>(),
    );
    expect(storage.entries['securityKey'], '123456');
  });
}
