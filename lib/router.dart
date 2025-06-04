import 'package:bb_mobile/features/app_unlock/ui/app_unlock_router.dart';
import 'package:bb_mobile/features/buy/ui/buy_router.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/key_server/ui/key_server_router.dart';
import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:bb_mobile/features/receive/ui/receive_router.dart';
import 'package:bb_mobile/features/sell/ui/sell_router.dart';
import 'package:bb_mobile/features/send/ui/send_router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/swap/ui/swap_router.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/ui/screens/route_error_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The main router of the app. It is the root of the routing tree and contains
/// all the entry-level routes.
class AppRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: WalletRoute.walletHome.path,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          final isSuperuser = context.select(
            (SettingsCubit cubit) => cubit.state.isSuperuser ?? false,
          );
          return Scaffold(
            body: navigationShell,
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: navigationShell.currentIndex,
              onTap: (index) {
                // Only supersusers can navigate to the exchange tab
                if (index == 1 && !isSuperuser) {
                  return;
                }
                navigationShell.goBranch(index);
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.currency_bitcoin),
                  label: 'Wallet',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.attach_money),
                  label: 'Exchange',
                ),
              ],
            ),
          );
        },
        branches: [
          StatefulShellBranch(routes: [WalletRouter.walletHomeRoute]),
          StatefulShellBranch(routes: [ExchangeRouter.exchangeHomeRoute]),
        ],
      ),
      OnboardingRouter.route,
      AppUnlockRouter.route,
      WalletRouter.walletDetailRoute,
      SettingsRouter.route,
      TransactionsRouter.transactionsRoute,
      TransactionsRouter.transactionDetailsRoute,
      ReceiveRouter.route,
      SendRouter.route,
      SwapRouter.route,
      BuyRouter.route,
      SellRouter.route,
      KeyServerRouter.route,
    ],
    errorBuilder: (context, state) => const RouteErrorScreen(),
  );
}
