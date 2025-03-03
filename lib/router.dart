import 'package:bb_mobile/_ui/screens/route_error_screen.dart';
import 'package:bb_mobile/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/app_unlock/ui/pin_code_unlock_screen.dart';
import 'package:bb_mobile/home/ui/home_screen.dart';
import 'package:bb_mobile/receive/ui/receive_router.dart';
import 'package:bb_mobile/recover_wallet/ui/recover_wallet_flow.dart';
import 'package:bb_mobile/settings/ui/screens/settings_screen.dart';
import 'package:bb_mobile/settings/ui/settings_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

// These are the main routes of the app, the ones that are not nested in other
//  routes and so are reachable from anywhere in the app.
enum AppRoute {
  onboarding('/onboarding'),
  home('/'),
  appUnlock('/app-unlock'),
  recoverWallet('/recover-wallet'),
  settings('/settings'),
  receiveBitcoin('/receive-bitcoin'),
  receiveLightning('/receive-lightning'),
  receiveLiquid('/receive-liquid');

  final String path;

  const AppRoute(this.path);
}

class AppRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoute.home.path,
    routes: [
      GoRoute(
        name: AppRoute.home.name,
        path: AppRoute.home.path,
        redirect: (context, state) {
          // Check AppStartupState to skip onboarding if user has existing wallets
          final appStartupState = context.read<AppStartupBloc>().state;
          if (appStartupState is AppStartupSuccess &&
              appStartupState.isPinCodeSet) {
            return AppRoute.appUnlock.path;
          }

          return null;
        },
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: HomeScreen()),
      ),
      GoRoute(
        name: AppRoute.appUnlock.name,
        path: AppRoute.appUnlock.path,
        builder: (context, state) {
          final onSuccess = state.extra as VoidCallback?;

          return PinCodeUnlockScreen(onSuccess: onSuccess);
        },
      ),
      GoRoute(
        name: AppRoute.recoverWallet.name,
        path: AppRoute.recoverWallet.path,
        builder: (context, state) => const RecoverWalletFlow(),
      ),
      GoRoute(
        name: AppRoute.settings.name,
        path: AppRoute.settings.path,
        builder: (context, state) => const SettingsScreen(),
        routes: SettingsRouter.routes,
      ),
      ReceiveRouter.route,
    ],
    errorBuilder: (context, state) => const RouteErrorScreen(),
  );
}
