import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/app_unlock/domain/app_unlock_failure.dart';
import 'package:secrets/secrets.dart';

class CheckPinCodeExistsUsecase {
  final AccessKeychain _accessKeychain;

  CheckPinCodeExistsUsecase({required this._accessKeychain});

  Future<Result<bool, AppUnlockFailure>> execute() async =>
      (await _accessKeychain.isPinSet()).mapErr(
        (failure) => switch (failure) {
          KeystoreLockedFailure() => const AppUnlockKeychainLockedFailure(),
          _ => const AppUnlockPinCheckFailure(),
        },
      );
}
