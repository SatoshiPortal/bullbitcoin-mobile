import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/pin_code/domain/pin_code_failure.dart';
import 'package:secrets/secrets.dart';

class PinCodeRepository {
  final AppUnlockCredential _pin;

  PinCodeRepository(this._pin);

  Future<Result<bool, PinCodeFailure>> isPinCodeSet() async =>
      (await _pin.exists()).mapErr(_readFailure);

  Future<Result<Null, PinCodeFailure>> setPinCode(String pinCode) async =>
      (await _pin.set(
        pinCode,
      )).map((_) => null).mapErr((_) => const PinCodeSaveFailure());

  Future<Result<bool, PinCodeFailure>> verifyPinCode(String pinCode) async =>
      (await _pin.verify(pinCode)).mapErr(_readFailure);

  Future<Result<Null, PinCodeFailure>> deletePinCode() async =>
      (await _pin.delete())
          .map((_) => null)
          .mapErr((_) => const PinCodeDeleteFailure());

  static PinCodeFailure _readFailure(SecretFailure failure) =>
      switch (failure) {
        KeystoreLockedFailure() => const PinCodeKeychainLockedFailure(),
        SecretNotFoundFailure() => const PinCodeNotSetFailure(),
        _ => PinCodeUnexpectedFailure(failure.logMessage),
      };
}
