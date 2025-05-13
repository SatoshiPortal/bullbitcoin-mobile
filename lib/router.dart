import 'package:bb_mobile/features/app_unlock/ui/app_unlock_router.dart';
import 'package:bb_mobile/features/home/ui/home_router.dart';
import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:bb_mobile/ui/screens/route_error_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The main router of the app. It is the root of the routing tree and contains
/// all the entry-level routes.
class AppRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: HomeRoute.home.path,
    routes: [OnboardingRouter.route, AppUnlockRouter.route, HomeRouter.route],
    errorBuilder: (context, state) => const RouteErrorScreen(),
  );
}
