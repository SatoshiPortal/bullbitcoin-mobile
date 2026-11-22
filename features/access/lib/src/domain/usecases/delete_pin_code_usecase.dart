import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:access/src/domain/access_failure.dart';

class DeletePinCodeUsecase {
  final AccessKeychain _accessKeychain;
  DeletePinCodeUsecase({required this._accessKeychain});

  Future<Result<Null, AccessFailure>> execute() async =>
      switch (await _accessKeychain.deletePin()) {
        Ok() => const Ok(null),
        Err(failure: KeystoreLockedFailure()) => const Err(
          AccessPinDeleteFailure(),
        ),
        Err(:final failure) => Err(
          AccessPinSettingsUnexpectedFailure(failure.logMessage),
        ),
      };
}
