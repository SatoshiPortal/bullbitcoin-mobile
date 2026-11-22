import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:access/src/domain/access_failure.dart';

class SetPinCodeUsecase {
  final AccessKeychain _accessKeychain;
  SetPinCodeUsecase({required this._accessKeychain});

  Future<Result<Null, AccessFailure>> execute(String pinCode) async =>
      switch (await _accessKeychain.setPin(pinCode)) {
        Ok() => const Ok(null),
        Err(failure: KeystoreLockedFailure()) => const Err(
          AccessPinSaveFailure(),
        ),
        Err(:final failure) => Err(
          AccessPinSettingsUnexpectedFailure(failure.logMessage),
        ),
      };
}
