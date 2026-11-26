import 'package:access/src/domain/access_failure.dart';
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
