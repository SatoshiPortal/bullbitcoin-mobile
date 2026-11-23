import 'package:all_seed_view/setup.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_ark/ark_ui_setup.dart';
import 'package:bull_exchange/bull_exchange.dart'
    show BuyRoute, ExchangeHomeAction;
import 'package:bb_mobile/features/exchange/ui/exchange_purchase_binding.dart';
import 'package:bitcoin_price/bitcoin_price.dart';
import 'package:bb_mobile/features/support/public/support_facade.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:btc_map/btc_map.dart';
import 'package:bb_mobile/features/wallet/presentation/network_wallet_setup_cubit.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';

import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/app_startup/public/app_startup_facade.dart'
    show RouteErrorScreen;
import 'package:announcements/setup.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart'
    show SwapFacade;
import 'package:access/setup.dart';
import 'package:label_editor/setup.dart';
import 'package:labels/labels.dart';
import 'package:bip85/bip85.dart';
import 'package:signers/routes.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/router.dart';
import 'package:bb_mobile/features/coins/public/coins.dart';
import 'package:bb_mobile/features/consolidation/ui/consolidation_router.dart';
import 'package:bb_mobile/features/limit_orders/public/limit_orders_facade.dart';
import 'package:network/network.dart';
import 'package:settings/settings.dart';
import 'package:fees_feature/fees_feature.dart' show FeesFeature;
import 'package:swap_feature/swap_feature.dart' show SwapFeature;
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/import_coldcard/router.dart';
import 'package:bb_mobile/features/import_mnemonic/router.dart';
import 'package:wallet_import/wallet_import.dart';
import 'package:bb_mobile/features/import_wallet/router.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_router.dart';
import 'package:bb_mobile/features/onboarding/ui/onboarding_router.dart';
import 'package:bb_mobile/features/pay/public/pay_facade.dart';
import 'package:bb_mobile/features/receive/ui/receive_router.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bb_mobile/features/wallet/public/recoverbull_bindings.dart';
import 'package:bb_mobile/features/replace_by_fee/router.dart';
import 'package:bb_mobile/features/send/public/send_route.dart';
import 'package:bb_mobile/features/send/public/send_route_args.dart';
import 'package:bb_mobile/features/sell/public/sell_facade.dart';
import 'package:bb_mobile/features/send/ui/send_router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_hub_bindings.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:silent/setup.dart';
import 'package:bb_mobile/features/swap/ui/swap_router.dart';
import 'package:transactions/routes.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/backup_warning_overlay.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_home_app_bar.dart';
import 'package:bb_mobile/features/wallet/public/silent_bindings.dart'
    show SilentWalletPresentation;
import 'package:bb_mobile/features/wallet/public/ark_foreground_setup.dart';
import 'package:bb_mobile/locator.dart';
import 'package:material_ui/material_ui.dart';
import 'package:preferences/preferences.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// The main router of the app. It is the root of the routing tree and contains
/// all the entry-level routes.
class AppRouter {
  static SilentFeature mountSilent({
    required GetIt locator,
    required ReadSilentFingerprint readDefaultFingerprint,
  }) => SilentFeature.mount(
    preferences: locator(),
    secrets: locator(),
    readDefaultFingerprint: readDefaultFingerprint,
    readRouteAccess: (context) {
      final settings = context.read<SettingsCubit>().state;
      return (
        environment: settings.environment?.networkEnv,
        isSuperuser: settings.isSuperuser ?? false,
        isDevModeEnabled: settings.isDevModeEnabled ?? false,
      );
    },
    walletHomePath: WalletRoute.walletHome.path,
    openSend: (context) =>
        context.pushNamed(SendRoute.send.name, extra: const SendRouteArgs.sp()),
    balanceBuilder: SilentWalletPresentation.balance,
    settingsIconBuilder: SilentWalletPresentation.settingsIcon,
  );
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'rootNav');

  static final _exchangeConfig = ExchangeRouterConfig(
    networkUnavailable: () => locator<ExchangeFacade>().networkUnavailable(),
    loadKyc: () => locator<Exchange>().loadKyc(),
    isSuperuser: (context) =>
        context.read<SettingsCubit>().state.isSuperuser ?? false,
    homePath: WalletRoute.walletHome.path,
    onExit: (context) => context.goNamed(WalletRoute.walletHome.name),
    onOpenSettings: SettingsNavigation.open,
    onAction: (context, action) => _openQuickAction(context, switch (action) {
      ExchangeHomeAction.buy => QuickAction.buy,
      ExchangeHomeAction.sell => QuickAction.sell,
      ExchangeHomeAction.pay => QuickAction.pay,
      ExchangeHomeAction.transfer => QuickAction.transfer,
    }),
  );

  static void _openQuickAction(BuildContext context, QuickAction action) {
    switch (action) {
      case QuickAction.toggleAmounts:
        SettingsFacade.toggleAmountVisibility(context);
      case QuickAction.map:
        context.pushNamed(BtcMapFeature.routeName);
      case QuickAction.transfer:
        context.pushNamed(SwapRoute.swap.name);
      case QuickAction.history:
        TransactionsNavigation.openHistory(context);
      case QuickAction.support:
        SupportFacade.contactSupport(context);
      case QuickAction.priceHistory:
        BitcoinPriceFeature.openHistory(context);
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

  static final _exchangeFeature = ExchangeRouter.mount(
    _exchangeConfig,
    exchange: () => locator<Exchange>(),
    preferences: () => locator<Preferences>(),
    settings: SettingsRouter.exchangeSettingsHost,
    purchases: exchangePurchaseHost(locator),
  );

  static void _onBackupTestSucceeded(BuildContext context) {
    WalletRecoverBullBindings.tested(context);
    router.goNamed(WalletRoute.walletHome.name);
  }

  static final _announcements = AnnouncementsFeature.mount(
    dismissals: locator<AnnouncementDismissals>(),
    isAppUpdateRequired: () => locator<SwapFacade>().isAppUpdateRequired,
    watchAppUpdateRequired: () =>
        locator<SwapFacade>().watchAppUpdateRequired(),
    openPayjoinSettings: (context) =>
        context.pushNamed(SettingsRoute.payjoinSettings.name),
  );

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    onEnter: ExchangeTradingGuard(
      locator<ExchangeFacade>(),
      rootNavigatorKey,
    ).onEnter,
    initialLocation: WalletRoute.walletHome.path,
    // Breadcrumbs only — `enableAutoTransactions: false` skips the
    // performance/TTID instrumentation so we stay within the
    // error-reporting scope (consent-gated) rather than perf tracing.
    observers: [SentryNavigatorObserver(enableAutoTransactions: false)],
    redirect: (context, state) =>
        locator<SilentFeature>().redirect(context, state.uri.path),
    routes: [
      // An admitted regtest Ark profile serves the feature; others stay closed.
      ...(locator.isRegistered<ArkForegroundHost>()
          ? locator<ArkForegroundHost>().routes
          : createArkUnavailableRoutes()),
      ShellRoute(
        notifyRootObserver: true,
        builder: (context, state, child) {
          final location = state.uri.toString();
          final tabIndex = location.startsWith(ExchangeRoute.exchangeHome.path)
              ? 1
              : 0;

          final shell = PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              context.goNamed(WalletRoute.walletHome.name);
            },
            child: BackupWarningOverlay(
              child: Scaffold(
                // The app bar of the exchange tab is rendered by the
                // ExchangeHomeScreen itself, as an overlay.
                appBar: tabIndex == 0
                    ? WalletHomeAppBar(
                        onSettings: () => SettingsNavigation.open(context),
                      )
                    : null,
                extendBodyBehindAppBar: true,
                body: child,
              ),
            ),
          );
          return locator<BitcoinPriceFeature>().provideEmbeddedChart(
            child: shell,
          );
        },
        routes: [
          WalletRouter.walletHomeRoute(
            arkHost: locator.isRegistered<ArkForegroundHost>()
                ? locator<ArkForegroundHost>()
                : null,
            quickActions: locator<QuickActionsCubit>(),
            onQuickAction: _openQuickAction,
            onCustomizeQuickActions: (context) =>
                context.pushNamed(SettingsRoute.quickActions.name),
            createSetupCubit: () => locator<NetworkWalletSetupCubit>(),
            announcements: () => _announcements.carousel(),
          ),
          ...ExchangeRouter.routes(
            _exchangeConfig,
            exchangeFeature: _exchangeFeature,
          ),
        ],
      ),
      ?_exchangeFeature.authRoute,
      ?_exchangeFeature.supportChatRoute,
      OnboardingRouter.route,
      ...locator<AccessFeature>().routes.root,
      WalletRouter.walletDetailRoute(
        scopeWalletHistory: locator<TransactionsFeature>().scopeWalletHistory,
        loadCoinSummary: (id) => locator<Coins>().summary(id),
        onOpenCoins: (context, wallet) =>
            context.pushNamed<void>(CoinsRoute.coins.name, extra: wallet),
      ),
      ConsolidationRouter.route,
      SettingsFeature.mount(
        menuOf: SettingsHubBindings.menuOf,
        labelsOf: SettingsHubBindings.labelsOf,
        menuScope: SettingsHubBindings.menuScope,
        status: locator<NetworkFeature>().status,
        childRoutes: SettingsRouter.childRoutes(
          accessRoutes: locator<AccessFeature>().routes.settings,
          exchangeSettingsRoutes: _exchangeFeature.settingsRoutes,
          appSettingsRoutes: locator<NetworkFeature>().routes.appSettings,
          onBackupTestSucceeded: _onBackupTestSucceeded,
          priceRoutes: locator<BitcoinPriceFeature>().routes,
        ),
      ).route,
      ...locator<TransactionsFeature>().routes,
      ReceiveRouter.route,
      SendRouter.route(
        openSignedTransactionReader: (context, prepared, network) =>
            context.pushNamed<String>(
              BroadcastSignedTxRoute.broadcastHome.name,
              extra: (prepared: prepared, network: network),
            ),
      ),
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
      ...locator<SwapFeature>().routes,
      ..._exchangeFeature.buyRoutes,
      ..._exchangeFeature.fundingRoutes,
      SellRouter.route,
      ?_exchangeFeature.withdrawalRoute,
      PayRouter.route,
      ImportMnemonicRouter.route,
      ImportWatchOnlyRouter.route,
      BroadcastSignedTxRouter.route,
      ...locator<SignersFeature>().routes,
      ImportWalletRouter.route,
      ...ImportColdcardRouter.routes,
      ?_exchangeFeature.dcaRoute,
      ?_exchangeFeature.autoBuy,
      LimitOrdersRouter.create,
      ?_exchangeFeature.limitOrderDetails,
      ReplaceByFeeRouter.route,
      locator<Bip85Feature>().route,
      ...locator<NetworkFeature>().routes.root,
      ...locator<FeesFeature>().routes,
      ...locator<SilentFeature>().routes,
      ...locator<ImportFeature>().routes,
      locator<RecoverBullFeature>().route(
        copiedMessage: (context) => context.loc.copiedToClipboard,
        onRecovered: (context) {
          WalletRecoverBullBindings.recovered(context);
          router.goNamed(WalletRoute.walletHome.name);
        },
        onTested: _onBackupTestSucceeded,
        onOpenTorSettings: (context) =>
            NetworkNavigation.open(context, section: NetworkSection.tor),
      ),
      ...LabelEditorFeature.mount(labels: () => locator<Labels>()).routes,
      BtcMapFeature.route,
    ],
    errorBuilder: (context, state) => const RouteErrorScreen(),
  );
}
