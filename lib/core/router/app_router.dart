import 'package:bb_mobile/core/router/route_error_screen.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/app_unlock/presentation/screens/pin_code_unlock_screen.dart';
import 'package:bb_mobile/features/home/presentation/home_screen.dart';
import 'package:bb_mobile/features/onboarding/presentation/onboarding_screen.dart';
import 'package:bb_mobile/features/recover_wallet/presentation/flow/recover_wallet_flow.dart';
import 'package:bb_mobile/features/settings/presentation/screens/settings_screen.dart';
import 'package:bb_mobile/features/settings/router/settings_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

enum AppRoute {
  onboarding('/onboarding'),
  recoverWallet('/recover-wallet'),
  home('/home'),
  unlock('/unlock'),
  settings('/settings'),
  receive('/receive'),
  send('/send');

  final String path;

  const AppRoute(this.path);
}

class AppRouter {
  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoute.onboarding.path,
    routes: [
      GoRoute(
        name: AppRoute.onboarding.name,
        path: AppRoute.onboarding.path,
        redirect: (context, state) {
          // Check AppStartupState to skip onboarding if user has existing wallets
          final appStartupState = context.read<AppStartupBloc>().state;
          if (appStartupState is AppStartupSuccess &&
              appStartupState.hasExistingWallets) {
            // First thing to do is unlock the app if user has existing wallets
            return AppRoute.unlock.path;
          }

          return null;
        },
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        name: AppRoute.recoverWallet.name,
        path: AppRoute.recoverWallet.path,
        builder: (context, state) => const RecoverWalletFlow(),
      ),
      GoRoute(
        name: AppRoute.home.name,
        path: AppRoute.home.path,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        name: AppRoute.unlock.name,
        path: AppRoute.unlock.path,
        builder: (context, state) {
          // If no onSuccess callback is passed, navigate to home screen on success
          final onSuccess = state.extra as VoidCallback? ??
              () => GoRouter.of(context).goNamed(AppRoute.home.name);

          return PinCodeUnlockScreen(onSuccess: onSuccess);
        },
      ),
      GoRoute(
        name: AppRoute.settings.name,
        path: AppRoute.settings.path,
        builder: (context, state) => const SettingsScreen(),
        routes: SettingsRoutes
            .routes, // Todo: Replace with base Settings screen once PinCode feature is showcased
      ),
      GoRoute(
        name: AppRoute.receive.name,
        path: AppRoute.receive.path,
        builder: (context, state) => const Text('Receive'),
      ),
      GoRoute(
        name: AppRoute.send.name,
        path: AppRoute.send.path,
        builder: (context, state) => const Text('Send'),
      ),
    ],
    errorBuilder: (context, state) => const RouteErrorScreen(),
  );
}
