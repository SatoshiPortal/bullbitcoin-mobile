import 'package:access/src/domain/access_failure.dart';
import 'package:access/src/domain/access_lock_controller.dart';
import 'package:access/src/domain/access_lock_policy.dart' show LockSuspension;
import 'package:access/src/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:access/src/locator.dart';
import 'package:access/src/ui/pin_code_unlock_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:primitives/primitives.dart';

final class AppUnlockGrant {
  const AppUnlockGrant._();
}

class Access {
  const Access();

  /// Revokes the current session immediately. A protected view requires its
  /// PIN again; an unprotected view can reopen on foreground resume after
  /// admitted writes drain.
  Future<void> lock() => accessLocator<AccessLockController>().lock();

  /// True on every lock, false on every unlock.
  Stream<bool> get locked => accessLocator<AccessLockController>().locked;

  /// Holds the automatic lock off while a flow leaves the app on purpose
  /// (scanner, file picker, Google sign-in, the OS biometric prompt).
  LockSuspension suspendAutoLock(String reason) =>
      accessLocator<AccessLockController>().suspendAutoLock(reason);

  /// Feeds the app lifecycle to the lock policy (D93: sixty seconds).
  void onLifecycle(AppLifecycleState state) =>
      accessLocator<AccessLockController>().onLifecycle(state);

  Future<Result<bool, AccessFailure>> checkPinCodeExists() =>
      accessLocator<CheckPinCodeExistsUsecase>().execute();

  Widget buildReauthenticationGate({
    required ValueChanged<AppUnlockGrant> onSuccess,
    bool canPop = false,
  }) {
    return PinCodeUnlockScreen(
      onSuccess: () => onSuccess(const AppUnlockGrant._()),
      canPop: canPop,
    );
  }
}
