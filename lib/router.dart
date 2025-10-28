import 'dart:io';

import 'package:bb_mobile/core/screens/route_error_screen.dart';
import 'package:bb_mobile/features/app_unlock/ui/app_unlock_router.dart';
import 'package:bb_mobile/features/ark/router.dart';
import 'package:bb_mobile/features/ark_setup/router.dart';
import 'package:bb_mobile/features/bip85_entropy/router.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/router.dart';
import 'package:bb_mobile/features/buy/ui/buy_router.dart';
import 'package:bb_mobile/features/connect_hardware_wallet/router.dart';
import 'package:bb_mobile/features/dca/ui/dca_router.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/routing/electrum_settings_router.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/fund_exchange/ui/fund_exchange_router.dart';
import 'package:bb_mobile/features/import_coldcard_q/router.dart';
import 'package:bb_mobile/features/import_mnemonic/router.dart';
import 'package:bb_mobile/features/import_qr_device/router.dart';
import 'package:bb_mobile/features/import_wallet/router.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_router.dart';
import 'package:bb_mobile/features/key_server/ui/key_server_router.dart';
import 'package:bb_mobile/features/ledger/ui/ledger_router.dart';
import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:bb_mobile/features/pay/ui/pay_router.dart';
import 'package:bb_mobile/features/psbt_flow/psbt_router.dart';
import 'package:bb_mobile/features/receive/ui/receive_router.dart';
import 'package:bb_mobile/features/recoverbull/router.dart';
import 'package:bb_mobile/features/recoverbull_google_drive/router.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/router.dart';
import 'package:bb_mobile/features/recoverbull_vault_recovery/router.dart';
import 'package:bb_mobile/features/replace_by_fee/router.dart';
import 'package:bb_mobile/features/sell/ui/sell_router.dart';
import 'package:bb_mobile/features/send/ui/send_router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/swap/ui/swap_router.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_home_app_bar.dart';
import 'package:bb_mobile/features/withdraw/ui/withdraw_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
          final isExchangeLanding = location.contains(
            ExchangeRoute.exchangeLanding.path,
          );

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              context.goNamed(WalletRoute.walletHome.name);
            },
            child: Scaffold(
              // The app bar of the exchange tab is done with a sliver app bar
              // on the ExchangeHomeScreen itself.
              appBar: tabIndex == 0 ? const WalletHomeAppBar() : null,
              extendBodyBehindAppBar: true,
              body: child,
              bottomNavigationBar:
                  isExchangeLanding
                      ? null
                      : BottomNavigationBar(
                        currentIndex: tabIndex,
                        onTap: (index) {
                          if (index == 0) {
                            context.goNamed(WalletRoute.walletHome.name);
                          } else {
                            // Exchange tab
                            if (Platform.isIOS) {
                              final isSuperuser =
                                  context
                                      .read<SettingsCubit>()
                                      .state
                                      .isSuperuser ??
                                  false;
                              if (isSuperuser) {
                                context.goNamed(
                                  ExchangeRoute.exchangeHome.name,
                                );
                              } else {
                                context.goNamed(
                                  ExchangeRoute.exchangeLanding.name,
                                );
                              }
                            } else {
                              context.goNamed(ExchangeRoute.exchangeHome.name);
                            }
                          }
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
      WithdrawRouter.route,
      PayRouter.route,
      KeyServerRouter.route,
      ImportMnemonicRouter.route,
      ImportWatchOnlyRouter.route,
      BroadcastSignedTxRouter.route,
      PsbtRouterConfig.route,
      ImportWalletRouter.route,
      ImportColdcardRouter.route,
      ...LedgerRouter.routes,
      DcaRouter.route,
      ReplaceByFeeRouter.route,
      Bip85EntropyRouter.route,
      RecoverBullSelectVaultRouter.route,
      RecoverBullVaultRecoveryRouter.route,
      ElectrumSettingsRouter.route,
      ArkSetupRouter.route,
      ArkRouter.route,
      ...ImportQrDeviceRouter.routes,
      ConnectHardwareWalletRouter.route,
      RecoverBullRouter.route,
      RecoverBullGoogleDriveRouter.route,
    ],
    errorBuilder: (context, state) => const RouteErrorScreen(),
  );
}
