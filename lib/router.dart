import 'package:bb_mobile/core/screens/route_error_screen.dart';
import 'package:bb_mobile/features/app_unlock/ui/app_unlock_router.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/router.dart';
import 'package:bb_mobile/features/buy/ui/buy_router.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/fund_exchange/ui/fund_exchange_router.dart';
import 'package:bb_mobile/features/import_mnemonic/router.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_router.dart';
import 'package:bb_mobile/features/key_server/ui/key_server_router.dart';
import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:bb_mobile/features/psbt_flow/psbt_router.dart';
import 'package:bb_mobile/features/receive/ui/receive_router.dart';
import 'package:bb_mobile/features/sell/ui/sell_router.dart';
import 'package:bb_mobile/features/send/ui/send_router.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/swap/ui/swap_router.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_home_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The main router of the app. It is the root of the routing tree and contains
/// all the entry-level routes.
class AppRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'rootNav');

  static final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: WalletRoute.walletHome.path,
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          final location = state.uri.toString();
          final tabIndex =
              location.startsWith(ExchangeRoute.exchangeHome.path) ? 1 : 0;

          return Scaffold(
            // The app bar of the exchange tab is done with a sliver app bar
            // on the ExchangeHomeScreen itself.
            appBar: tabIndex == 0 ? const WalletHomeAppBar() : null,
            extendBodyBehindAppBar: true,
            body: child,
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: tabIndex,
              onTap: (index) {
                final goNamed =
                    index == 0
                        ? WalletRoute.walletHome.name
                        : ExchangeRoute.exchangeHome.name;

                context.goNamed(goNamed);
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
        routes: [WalletRouter.walletHomeRoute, ...ExchangeRouter.routes],
      ),
      OnboardingRouter.route,
      AppUnlockRouter.route,
      WalletRouter.walletDetailRoute,
      SettingsRouter.route,
      TransactionsRouter.transactionsRoute,
      ...TransactionsRouter.transactionDetailsRoutes,
      ReceiveRouter.route,
      SendRouter.route,
      SwapRouter.route,
      ...BuyRouter.routes,
      FundExchangeRouter.route,
      SellRouter.route,
      KeyServerRouter.route,
      ImportMnemonicRouter.route,
      ImportWatchOnlyRouter.route,
      BroadcastSignedTxRouter.route,
      PsbtRouterConfig.route,
    ],
    errorBuilder: (context, state) => const RouteErrorScreen(),
  );
}
