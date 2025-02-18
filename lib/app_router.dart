import 'package:bb_mobile/core/presentation/screens/route_error_screen.dart';
import 'package:bb_mobile/features/app_unlock/app_unlock_router.dart';
import 'package:bb_mobile/features/home/home_router.dart';
import 'package:bb_mobile/features/language/language_router.dart';
import 'package:bb_mobile/features/onboarding/onboarding_router.dart';
import 'package:bb_mobile/features/pin_code/pin_code_router.dart';
import 'package:bb_mobile/features/receive/receive_router.dart';
import 'package:bb_mobile/features/recover_wallet/recover_wallet_router.dart';
import 'package:bb_mobile/features/settings/settings_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: OnboardingRoute.onboarding.path,
    routes: [
      OnboardingRouter.route,
      RecoverWalletRouter.route,
      HomeRouter.route,
      PinCodeRouter.route,
      AppUnlockRouter.route,
      LanguageRouter.route,
      SettingsRouter.route,
      ReceiveRouter.route,
    ],
    errorBuilder: (context, state) => const RouteErrorScreen(),
  );
}
