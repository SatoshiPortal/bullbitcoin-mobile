import 'package:bb_mobile/features/bitcoin_price/public/bitcoin_price_facade.dart';
import 'package:bb_mobile/features/exchange_access/public/exchange_access_facade.dart';
import 'package:bb_mobile/features/support/public/support_facade.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'dart:io';

import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/screens/route_error_screen.dart';
import 'package:bb_mobile/features/announcements/presentation/announcements_cubit.dart';
import 'package:bb_mobile/features/autobuy/public/autobuy_facade.dart';
import 'package:bb_mobile/features/app_unlock/ui/app_unlock_router.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/bip85_entropy/router.dart';
import 'package:bb_mobile/features/bitbox/ui/bitbox_router.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/router.dart';
import 'package:bb_mobile/features/buy/ui/buy_router.dart';
import 'package:bb_mobile/features/coins/public/coins_facade.dart';
import 'package:bb_mobile/features/consolidation/ui/consolidation_router.dart';
import 'package:bb_mobile/features/dca/ui/dca_router.dart';
import 'package:bb_mobile/features/limit_orders/public/limit_orders_facade.dart';
import 'package:bb_mobile/features/electrum_settings/frameworks/ui/routing/electrum_settings_router.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/mempool_settings/router.dart';
import 'package:bb_mobile/features/fund_exchange/fund_exchange_router.dart';
import 'package:bb_mobile/features/import_coldcard/router.dart';
import 'package:bb_mobile/features/import_mnemonic/router.dart';
import 'package:bb_mobile/features/import_qr_device/router.dart';
import 'package:bb_mobile/features/import_wallet/router.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_router.dart';
import 'package:bb_mobile/features/ledger/ui/ledger_router.dart';
import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:bb_mobile/features/pay/ui/pay_router.dart';
import 'package:bb_mobile/features/psbt_flow/psbt_router.dart';
import 'package:bb_mobile/features/receive/ui/receive_router.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bb_mobile/features/wallet/public/recoverbull_bindings.dart';
import 'package:bb_mobile/features/replace_by_fee/router.dart';
import 'package:bb_mobile/features/sell/ui/sell_router.dart';
import 'package:bb_mobile/features/send/public/send_facade.dart';
import 'package:bb_mobile/features/send/ui/send_router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/sp/ui/sp_router.dart';
import 'package:bb_mobile/features/status_check/router.dart';
import 'package:bb_mobile/features/swap/ui/swap_router.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/backup_warning_overlay.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_home_app_bar.dart';
import 'package:bb_mobile/features/withdraw/ui/withdraw_router.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// The main router of the app. It is the root of the routing tree and contains
/// all the entry-level routes.
class AppRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'rootNav');

  static final _exchangeConfig = ExchangeRouterConfig(
    isSuperuser: (context) =>
        context.read<SettingsCubit>().state.isSuperuser ?? false,
    homePath: WalletRoute.walletHome.path,
    buildHomeCards: () => [locator<LimitOrdersFacade>().buildDashboardCard()],
    onHomeRefresh: () => locator<LimitOrdersFacade>().refreshDashboard(),
    onExit: (context) => context.goNamed(WalletRoute.walletHome.name),
    onOpenSettings: (context) => context.pushNamed(SettingsRoute.settings.name),
    onAction: (context, action) => _openQuickAction(context, switch (action) {
      ExchangeHomeAction.buy => QuickAction.buy,
      ExchangeHomeAction.sell => QuickAction.sell,
      ExchangeHomeAction.pay => QuickAction.pay,
      ExchangeHomeAction.transfer => QuickAction.transfer,
    }),
  );

  static void _openQuickAction(BuildContext context, QuickAction action) {
    switch (action) {
      case QuickAction.map:
        context.pushNamed(SettingsRoute.btcMap.name);
      case QuickAction.transfer:
        context.pushNamed(SwapRoute.swap.name);
      case QuickAction.history:
        context.pushNamed(TransactionsRoute.transactions.name);
      case QuickAction.settings:
        context.pushNamed(SettingsRoute.settings.name);
      case QuickAction.support:
        SupportFacade.contactSupport(context);
      case QuickAction.priceHistory:
        context.pushNamed(SettingsRoute.priceHistory.name);
      case QuickAction.buy:
        context.pushNamed(BuyRoute.buy.name);
      case QuickAction.sell:
        context.pushNamed(SellRoute.sell.name);
      case QuickAction.pay:
        context.pushNamed(PayRoute.pay.name);
      case QuickAction.exchange:
        context.pushNamed(ExchangeRoute.exchangeHome.name);
    }
  }

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: WalletRoute.walletHome.path,
    // Breadcrumbs only — `enableAutoTransactions: false` skips the
    // performance/TTID instrumentation so we stay within the
    // error-reporting scope (consent-gated) rather than perf tracing.
    observers: [SentryNavigatorObserver(enableAutoTransactions: false)],
    redirect: (BuildContext context, GoRouterState state) {
      final path = state.uri.path;
      // Only read the gate providers for SP routes; the decision itself lives
      // in the SP feature's pure `spRedirect` (unit-testable, no widget tree).
      if (!isSpPath(path)) return null;
      final settingsState = context.read<SettingsCubit>().state;
      return spRedirect(
        path,
        isSuperuser: settingsState.isSuperuser ?? false,
        isDevModeEnabled: settingsState.isDevModeEnabled ?? false,
        // The SP feature's own synchronous flag, not the wallet feature's copy:
        // that copy only lands a few turns after setup finishes, which bounced
        // any navigation to an SP route right after create back to setup.
        isSpWalletSetup: locator<SpFacade>().isSetUpNow,
        gateClosedRedirectPath: WalletRoute.walletHome.path,
      );
    },
    routes: [
      ShellRoute(
        notifyRootObserver: true,
        builder: (context, state, child) {
          final location = state.uri.toString();
          final tabIndex = location.startsWith(ExchangeRoute.exchangeHome.path)
              ? 1
              : 0;

          return MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => locator<PriceChartCubit>()),
              BlocProvider(
                create: (_) => locator<AnnouncementsCubit>()..refresh(),
              ),
            ],
            child: PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                context.goNamed(WalletRoute.walletHome.name);
              },
              child: BackupWarningOverlay(
                child: Scaffold(
                  // The app bar of the exchange tab is rendered by the
                  // ExchangeHomeScreen itself, as an overlay.
                  appBar: tabIndex == 0 ? const WalletHomeAppBar() : null,
                  extendBodyBehindAppBar: true,
                  body: child,
                ),
              ),
            ),
          );
        },
        routes: [
          WalletRouter.walletHomeRoute(
            quickActions: locator<QuickActionsFacade>(),
            exchangeAccess: locator<ExchangeAccessFacade>(),
            platformAllowsExchange: (context) =>
                !Platform.isIOS ||
                context.select(
                  (SettingsCubit cubit) => cubit.state.isSuperuser ?? false,
                ),
            onQuickAction: _openQuickAction,
            onCustomizeQuickActions: (context, available, defaults) =>
                context.pushNamed(SettingsRoute.quickActions.name),
          ),
          ...ExchangeRouter.routes(_exchangeConfig),
        ],
      ),
      ExchangeRouter.authRoute(_exchangeConfig),
      ExchangeRouter.supportChatRoute(_exchangeConfig),
      OnboardingRouter.route,
      AppUnlockRouter.route,
      WalletRouter.walletDetailRoute(
        onOpenCoins: (context, wallet) =>
            context.pushNamed<void>(CoinsRoute.coins.name, extra: wallet),
      ),
      ConsolidationRouter.route,
      SettingsRouter.route(
        buildPriceHistory: (context) => locator<BitcoinPriceFacade>()
            .buildHistory(onBack: () => context.pop()),
      ),
      TransactionsRouter.transactionsRoute,
      TransactionsRouter.exportTransactionsRoute,
      ...TransactionsRouter.transactionDetailsRoutes,
      ReceiveRouter.route,
      SendRouter.route,
      CoinsRouter.route(
        missingWalletRedirect: WalletRoute.walletHome.path,
        onSend: (context, wallet, outpoints) => context.pushNamed<void>(
          SendRoute.send.name,
          extra: SendRouteArgs.selected(wallet: wallet, outpoints: outpoints),
        ),
        onSweep: (context, wallet, outpoints) => context.pushNamed<void>(
          SendRoute.send.name,
          extra: SendRouteArgs.sweep(wallet: wallet, outpoints: outpoints),
        ),
      ),
      SwapRouter.route,
      ...BuyRouter.routes,
      ...FundExchangeRouter.routes,
      SellRouter.route,
      WithdrawRouter.route,
      PayRouter.route,
      ImportMnemonicRouter.route,
      ImportWatchOnlyRouter.route,
      BroadcastSignedTxRouter.route,
      PsbtRouterConfig.route,
      ImportWalletRouter.route,
      ...ImportColdcardRouter.routes,
      ...LedgerRouter.routes,
      ...BitBoxRouter.routes,
      DcaRouter.route,
      AutoBuyRouter.route,
      ...LimitOrdersRouter.routes,
      ReplaceByFeeRouter.route,
      Bip85EntropyRouter.route,
      ElectrumSettingsRouter.route,
      MempoolSettingsRoute.route,
      SpSetupRouter.route(successRedirectPath: WalletRoute.walletHome.path),
      SpRouter.route(
        sendRouteName: SendRoute.send.name,
        sendRouteExtra: const SendRouteArgs.sp(),
        exitRedirectPath: WalletRoute.walletHome.path,
      ),
      ...ImportQrDeviceRouter.routes,
      locator<RecoverBullFeature>().route(
        copiedMessage: (context) => context.loc.copiedToClipboard,
        onRecovered: (context) {
          WalletRecoverBullBindings.recovered(context);
          router.goNamed(WalletRoute.walletHome.name);
        },
      ),
      LabelsRouter.route,
      StatusCheckRouter.route,
    ],
    errorBuilder: (context, state) => const RouteErrorScreen(),
  );
}
