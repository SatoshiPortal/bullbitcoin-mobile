import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:access/src/domain/access_failure.dart';

class IsPinCodeSetUsecase {
  final AccessKeychain _accessKeychain;
  IsPinCodeSetUsecase({required this._accessKeychain});

  Future<Result<bool, AccessFailure>> execute() async =>
      switch (await _accessKeychain.isPinSet()) {
        Ok(:final value) => Ok(value),
        Err(failure: KeystoreLockedFailure()) => const Err(
          AccessPinSettingsKeychainLockedFailure(),
        ),
        Err(:final failure) => Err(
          AccessPinSettingsUnexpectedFailure(failure.logMessage),
        ),
      };
}
