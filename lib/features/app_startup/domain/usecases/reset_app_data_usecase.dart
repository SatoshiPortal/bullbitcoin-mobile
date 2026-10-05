import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_failure.dart';
import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';
import 'package:bb_mobile/features/pin_code/domain/pin_code_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

// On iOS especially, some secure storage data might still be there after the app is uninstalled.
// This use case is used to reset the app data when the app is installed again.
class ResetAppDataUsecase {
  final PinCodeRepository _pinCodeRepository;

  ResetAppDataUsecase({required this._pinCodeRepository});

  /// Clears data a previous install left behind.
  ///
  /// The failure is propagated rather than ignored, which is not merely
  /// tidiness: this runs on the fresh-install path, and a stale PIN left in
  /// the keychain is not consulted this session but *is* consulted on the
  /// next launch once wallets exist — locking the user out with a PIN they
  /// never set.
  ///
  /// `deletePinCode` returns rather than throws, so there is nothing to
  /// catch; the mapping below is the whole of the boundary.
  @useResult
  Future<Result<void, AppStartupFailure>> execute() async {
    switch (await _pinCodeRepository.deletePinCode()) {
      case Ok():
        return const Ok(null);
      // Both arms mean "keychain sealed" today: deletePinCode maps
      //  KeychainLockedException to PinCodeDeleteFailure, while its sibling
      //  methods use PinCodeKeychainLockedFailure for the same cause. Matched
      //  together so this keeps working whichever one that feature settles
      //  on — and so a locked keychain reaches the splash-and-retry path
      //  instead of the terminal error screen.
      //
      //  KNOWN FRAGILITY, and the failure mode is not symmetric. If
      //  deletePinCode ever returns PinCodeDeleteFailure for a genuine,
      //  non-keychain delete failure, that lands here as "sealed" and the
      //  caller holds the splash for an unlock that never comes — the retry
      //  only fires on a lifecycle resume. The fix belongs in pin_code:
      //  return PinCodeKeychainLockedFailure like the sibling methods do,
      //  then delete the PinCodeDeleteFailure arm below.
      case Err(
        failure: PinCodeDeleteFailure() || PinCodeKeychainLockedFailure(),
      ):
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
