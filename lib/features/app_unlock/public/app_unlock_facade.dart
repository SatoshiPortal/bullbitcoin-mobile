import 'package:bb_mobile/features/app_unlock/ui/pin_code_unlock_screen.dart';
import 'package:flutter/widgets.dart';

final class AppUnlockGrant {
  const AppUnlockGrant._();
}

class AppUnlockFacade {
  const AppUnlockFacade();

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
