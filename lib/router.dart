import 'package:bb_mobile/features/app_unlock/ui/pin_code_unlock_screen.dart';
import 'package:bb_mobile/features/buy/ui/buy_screen.dart';
import 'package:bb_mobile/features/home/ui/home_screen.dart';
import 'package:bb_mobile/features/key_server/ui/key_server_flow.dart'
    show KeyServerFlow;
import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:bb_mobile/features/receive/ui/receive_router.dart';
import 'package:bb_mobile/features/sell/ui/sell_screen.dart';
import 'package:bb_mobile/features/send/ui/send_screen.dart';
import 'package:bb_mobile/features/settings/ui/screens/settings_screen.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/transactions/ui/screens/transactions_screen.dart';
import 'package:bb_mobile/ui/screens/dev_page.dart';
import 'package:bb_mobile/ui/screens/route_error_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// These are the main routes of the app, the ones that are not nested in other
//  routes and so are reachable from anywhere in the app.
enum AppRoute {
  onboarding('/onboarding'),
  home('/'),
  appUnlock('/app-unlock'),
  //todo; move to settings router
  recoverWallet('/recover-wallet'),
  recoverImportWallet('/recover-wallet-import'),
  keyServerFlow('/key-server-flow'),
  settings('/settings'),

  send('/send'),
  sell('/sell'),
  buy('/buy'),
  txs('/txs'),

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
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: rootNavigatorKey,
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
        name: AppRoute.keyServerFlow.name,
        path: AppRoute.keyServerFlow.path,
        builder: (context, state) {
          final (String? backupFile, String? flow, bool fromOnboarding) =
              state.extra! as (String?, String?, bool);
          return KeyServerFlow(
            backupFile: backupFile,
            currentFlow: flow,
            fromOnboarding: fromOnboarding,
          );
        },
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
      GoRoute(
        name: AppRoute.sell.name,
        path: AppRoute.sell.path,
        builder: (context, state) => const SellScreen(),
      ),
      GoRoute(
        name: AppRoute.buy.name,
        path: AppRoute.buy.path,
        builder: (context, state) => const BuyScreen(),
      ),
      GoRoute(
        name: AppRoute.txs.name,
        path: AppRoute.txs.path,
        builder: (context, state) => const TransactionsScreen(),
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
