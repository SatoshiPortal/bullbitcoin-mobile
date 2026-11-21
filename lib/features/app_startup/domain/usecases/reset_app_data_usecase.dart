import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_failure.dart';
import 'package:secrets/secrets.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

// On iOS especially, some secure storage data might still be there after the app is uninstalled.
// This use case is used to reset the app data when the app is installed again.
class ResetAppDataUsecase {
  final AccessKeychain _accessKeychain;

  ResetAppDataUsecase({required this._accessKeychain});

  /// Clears data a previous install left behind.
  ///
  /// The failure is propagated rather than ignored, which is not merely
  /// tidiness: this runs on the fresh-install path, and a stale PIN left in
  /// the keychain is not consulted this session but *is* consulted on the
  /// next launch once wallets exist — locking the user out with a PIN they
  /// never set.
  ///
  @useResult
  Future<Result<void, AppStartupFailure>> execute() async {
    switch (await _accessKeychain.deletePin()) {
      case Ok():
        return const Ok(null);
      case Err(failure: KeystoreLockedFailure()):
        return const Err(AppStartupKeychainLockedFailure());
      case Err(:final failure):
        log.severe(
          message: 'App data reset failed',
          error: failure,
          trace: StackTrace.current,
        );
        return const Err(AppStartupResetFailure());
    }
  }
}
