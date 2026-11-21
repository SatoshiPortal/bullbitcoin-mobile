import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/features/pin_code/domain/pin_code_failure.dart';

class SetPinCodeUsecase {
  final AccessKeychain _accessKeychain;
  SetPinCodeUsecase({required this._accessKeychain});

  Future<Result<Null, PinCodeFailure>> execute(
    String pinCode,
  ) async => switch (await _accessKeychain.setPin(pinCode)) {
    Ok() => const Ok(null),
    Err(failure: KeystoreLockedFailure()) => const Err(PinCodeSaveFailure()),
    Err(:final failure) => Err(PinCodeUnexpectedFailure(failure.logMessage)),
  };
}
