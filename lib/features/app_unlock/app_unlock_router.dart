import 'dart:ui';

import 'package:bb_mobile/features/app_unlock/presentation/screens/pin_code_unlock_screen.dart';
import 'package:bb_mobile/features/home/home_router.dart';
import 'package:go_router/go_router.dart';

enum AppUnlockRoute {
  unlock('/unlock');

  final String path;

  const AppUnlockRoute(this.path);
}

class AppUnlockRouter {
  static final route = GoRoute(
    name: AppUnlockRoute.unlock.name,
    path: AppUnlockRoute.unlock.path,
    builder: (context, state) {
      // If no onSuccess callback is passed, navigate to home screen on success
      final onSuccess = state.extra as VoidCallback? ??
          () => GoRouter.of(context).goNamed(HomeRoute.home.name);

      return PinCodeUnlockScreen(onSuccess: onSuccess);
    },
  );
}
