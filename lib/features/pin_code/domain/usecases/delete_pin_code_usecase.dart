import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/features/pin_code/domain/pin_code_failure.dart';

class DeletePinCodeUsecase {
  final AccessKeychain _accessKeychain;
  DeletePinCodeUsecase({required this._accessKeychain});

  Future<Result<Null, PinCodeFailure>> execute() async =>
      switch (await _accessKeychain.deletePin()) {
        Ok() => const Ok(null),
        Err(failure: KeystoreLockedFailure()) => const Err(
          PinCodeDeleteFailure(),
        ),
        Err(:final failure) => Err(
          PinCodeUnexpectedFailure(failure.logMessage),
        ),
      };
}
