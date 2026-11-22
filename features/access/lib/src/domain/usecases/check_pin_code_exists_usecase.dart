import 'package:primitives/primitives.dart';
import 'package:access/src/domain/access_failure.dart';
import 'package:secrets/secrets.dart';

class CheckPinCodeExistsUsecase {
  final AccessKeychain _accessKeychain;

  CheckPinCodeExistsUsecase({required this._accessKeychain});

  Future<Result<bool, AccessFailure>> execute() async =>
      (await _accessKeychain.isPinSet()).mapErr(
        (failure) => switch (failure) {
          KeystoreLockedFailure() => const AccessUnlockKeychainLockedFailure(),
          _ => const AccessPinCheckFailure(),
        },
      );
}
