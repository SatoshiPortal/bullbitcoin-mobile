import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/features/pin_code/domain/pin_code_failure.dart';

class IsPinCodeSetUsecase {
  final AccessKeychain _accessKeychain;
  IsPinCodeSetUsecase({required this._accessKeychain});

  Future<Result<bool, PinCodeFailure>> execute() async =>
      switch (await _accessKeychain.isPinSet()) {
        Ok(:final value) => Ok(value),
        Err(failure: KeystoreLockedFailure()) => const Err(
          PinCodeKeychainLockedFailure(),
        ),
        Err(:final failure) => Err(
          PinCodeUnexpectedFailure(failure.logMessage),
        ),
      };
}
