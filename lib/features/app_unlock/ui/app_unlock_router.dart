import 'package:flutter/widgets.dart';

import 'package:bb_mobile/features/app_unlock/ui/pin_code_unlock_screen.dart';
import 'package:go_router/go_router.dart';

enum AppUnlockRoute {
  appUnlock('/app-unlock');

  final String path;

  const AppUnlockRoute(this.path);
}

class AppUnlockRouter {
  static GoRoute route({required void Function(BuildContext) onUnlocked}) =>
      GoRoute(
        name: AppUnlockRoute.appUnlock.name,
        path: AppUnlockRoute.appUnlock.path,
        builder: (context, state) {
          final onSuccess = state.extra as VoidCallback?;

          return PinCodeUnlockScreen(
            onSuccess: onSuccess ?? () => onUnlocked(context),
          );
        },
      );
}
