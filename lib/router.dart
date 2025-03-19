import 'package:bb_mobile/_ui/screens/dev_page.dart';
import 'package:bb_mobile/_ui/screens/route_error_screen.dart';
import 'package:bb_mobile/app_unlock/ui/pin_code_unlock_screen.dart';
import 'package:bb_mobile/home/ui/home_screen.dart';
import 'package:bb_mobile/onboarding/ui/onboarding_router.dart';
import 'package:bb_mobile/receive/ui/receive_router.dart';
import 'package:bb_mobile/recover_wallet/ui/recover_wallet_flow.dart';
import 'package:bb_mobile/send/ui/send_screen.dart';
import 'package:bb_mobile/settings/ui/screens/settings_screen.dart';
import 'package:bb_mobile/settings/ui/settings_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// These are the main routes of the app, the ones that are not nested in other
//  routes and so are reachable from anywhere in the app.
enum AppRoute {
  onboarding('/onboarding'),
  home('/'),
  appUnlock('/app-unlock'),
  recoverWallet('/recover-wallet'),
  recoverImportWallet('/recover-wallet-import'),

  settings('/settings'),
  receiveBitcoin('/receive-bitcoin'),
  receiveLightning('/receive-lightning'),
  receiveLiquid('/receive-liquid'),

  send('/send'),

  devStart('/dev-start'),
  devReceive('/dev-receive'),
  devSend('/dev-send'),
  devSettings('/dev-settings'),
  devHome('/dev-home'),
  devRecover('/dev-recover'),
  devCreate('/dev-create'),
  devUnlock('/dev-unlock'),
  devSwap('/dev-swap'),
  devSettingsBitcoin('/dev-settings-bitcoin'),
  devSettingsSecurityPin('/dev-settings-security-pin'),
  devSettingsLanguage('/dev-settings-language'),
  devSettingsCurrency('/dev-settings-currency'),
  devBackup('/dev-backup'),
  devSettingsSwapHistory('/dev-settings-swap-history'),
  devSettingsBackup('/dev-settings-backup'),
  devSettingsTestBackup('/dev-settings-test-backup');

  final String path;

  const AppRoute(this.path);
}

class AppRouter {
  // static final GlobalKey<NavigatorState> rootNavigatorKey =
  //     GlobalKey<NavigatorState>();

  static final router = GoRouter(
    // navigatorKey: rootNavigatorKey,
    initialLocation: AppRoute.home.path,
    routes: [
      GoRoute(
        name: AppRoute.home.name,
        path: AppRoute.home.path,
        // redirect: (context, state) {
        //   // Check AppStartupState to skip onboarding if user has existing wallets
        //   // final appStartupState = context.read<AppStartupBloc>().state;
        //   // if (appStartupState is AppStartupSuccess &&
        //   //     appStartupState.isPinCodeSet) {
        //   //   return AppRoute.appUnlock.path;
        //   // }

        //   return null;
        // },
        builder: (context, state) {
          return const HomeScreen();
        },
        // pageBuilder: (context, state) =>
        // const NoTransitionPage(child: HomeScreen()),
      ),
      // GoRoute(
      //   name: AppRoute.onboarding.name,
      //   path: AppRoute.onboarding.path,
      //   builder: (context, state) {
      //     return const OnboardingScreen();
      //   },
      // ),
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
        builder: (context, state) =>
            const RecoverWalletFlow(fromOnboarding: true),
      ),
      GoRoute(
        name: AppRoute.recoverImportWallet.name,
        path: AppRoute.recoverImportWallet.path,
        builder: (context, state) => const RecoverWalletFlow(
          fromOnboarding: false,
        ),
      ),
      GoRoute(
        name: AppRoute.settings.name,
        path: AppRoute.settings.path,
        builder: (context, state) => const SettingsScreen(),
        routes: SettingsRouter.routes,
      ),
      GoRoute(
        name: AppRoute.send.name,
        path: AppRoute.send.path,
        builder: (context, state) => const SendScreen(),
      ),
      ReceiveRouter.route,
      DevPages.devStart,
      OnboardingRouter.route,
    ],
    errorBuilder: (context, state) => const RouteErrorScreen(),
  );
}

class DevPages {
  static final devStart = GoRoute(
    name: AppRoute.devStart.name,
    path: AppRoute.devStart.path,
    builder: (context, state) => DevPage(
      title: 'Dev',
      pages: [
        DevPageData(
          route: AppRoute.home.name,
          title: 'Home',
          done: true,
        ),
        DevPageData(
          route: AppRoute.recoverWallet.name,
          title: 'Recover',
          done: true,
        ),
        DevPageData(
          route: AppRoute.onboarding.name,
          title: 'Onboarding',
          done: true,
        ),
        DevPageData(
          route: AppRoute.devReceive.name,
          title: 'Receive',
        ),
        DevPageData(
          route: AppRoute.devCreate.name,
          title: 'Create',
        ),
        DevPageData(
          route: AppRoute.devSend.name,
          title: 'Send',
        ),
        DevPageData(
          route: AppRoute.devSettings.name,
          title: 'Settings',
        ),
        DevPageData(
          route: AppRoute.devUnlock.name,
          title: 'Unlock',
        ),
        DevPageData(
          route: AppRoute.devSwap.name,
          title: 'Swap',
        ),
        DevPageData(
          route: AppRoute.devBackup.name,
          title: 'Backup',
        ),
        DevPageData(
          route: AppRoute.devSettingsBitcoin.name,
          title: 'Settings Bitcoin',
        ),
        DevPageData(
          route: AppRoute.devSettingsSecurityPin.name,
          title: 'Settings Security Pin',
        ),
        DevPageData(
          route: AppRoute.devSettingsLanguage.name,
          title: 'Settings Language',
        ),
        DevPageData(
          route: AppRoute.devSettingsCurrency.name,
          title: 'Settings Currency',
        ),
        DevPageData(
          route: AppRoute.devSettingsSwapHistory.name,
          title: 'Settings Swap History',
        ),
        DevPageData(
          route: AppRoute.devSettingsBackup.name,
          title: 'Settings Backup',
        ),
        DevPageData(
          route: AppRoute.devSettingsTestBackup.name,
          title: 'Settings Test Backup',
        ),
      ],
    ),
  );
}
