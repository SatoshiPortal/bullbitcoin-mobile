import 'dart:ui';

import 'package:bb_mobile/features/pin_code/ui/pin_code_unlock_screen.dart';
import 'package:go_router/go_router.dart';

enum PinCodeRoute {
  appUnlock('/app-unlock');

  final String path;

  const PinCodeRoute(this.path);
}

class PinCodeRouter {
  static final route = GoRoute(
    name: PinCodeRoute.appUnlock.name,
    path: PinCodeRoute.appUnlock.path,
    builder: (context, state) {
      final onSuccess = state.extra as VoidCallback?;

      return PinCodeUnlockScreen(onSuccess: onSuccess);
    },
  );
}
