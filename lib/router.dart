import 'dart:async';

import 'package:address_view/routes.dart';
import 'package:all_seed_view/setup.dart' show AllSeedViewFeature;
import 'package:primitives/primitives.dart' show NetworkEnv;
import 'package:secrets/storage.dart';
import 'package:secrets/secrets.dart';
import 'package:backups/backups.dart';
import 'package:bull_recoverbull/storage.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_ark/ark_ui_setup.dart';
import 'package:bull_exchange/bull_exchange.dart'
    show BuyRoute, ExchangeHomeAction, ExchangeTradingGuard, PayRoute, SellRoute;
import 'package:bb_mobile/features/exchange/ui/exchange_purchase_binding.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_payin_binding.dart';
import 'package:bitcoin_price/bitcoin_price.dart';
import 'package:bull_ui/bull_ui.dart' show BullSnackBar;
import 'package:settings/settings.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:btc_map/btc_map.dart';
import 'package:bb_mobile/features/wallet/presentation/network_wallet_setup_cubit.dart';

import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:startup/startup.dart' show RouteErrorScreen;
import 'package:announcements/setup.dart';
import 'package:swaps/order_swaps.dart' show OrderSwaps;
import 'package:access/setup.dart';
import 'package:label_editor/setup.dart';
import 'package:labels/labels.dart';
import 'package:bip85/bip85.dart';
import 'package:signers/routes.dart';
import 'package:send/send.dart';
import 'package:send/setup.dart';
import 'package:electrum/electrum.dart' show Electrum;
import 'package:fees/fees.dart' show Fees;
import 'package:spend/spend.dart' show Spend;
import 'package:coins/coins.dart';
import 'package:coins/setup.dart';
import 'package:network/network.dart';
import 'package:fees_feature/fees_feature.dart' show FeesFeature;
import 'package:swap_feature/swap_feature.dart'
    show SwapFeature, SwapNavigation;
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:wallet_import/setup.dart';
import 'package:onboarding/setup.dart';
import 'package:receive/setup.dart' show ReceiveFeature;
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bb_mobile/features/wallet/public/recoverbull_bindings.dart';
import 'package:bb_mobile/features/send/public/send_route_args.dart';
import 'package:bb_mobile/features/send/ui/send_router.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:silent/setup.dart';
import 'package:transactions/routes.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_consolidation.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/backup_warning_overlay.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_home_app_bar.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/silent_wallet_balance.dart'
    show SilentWalletPresentation;
import 'package:bull_ark/ark_foreground_setup.dart';
import 'package:bb_mobile/locator.dart';
import 'package:material_ui/material_ui.dart';
import 'package:preferences/preferences.dart';
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
      final settings = Settings.readEnvironment(context);
      return (
        environment: settings.environment?.networkEnv,
        isSuperuser: settings.isSuperuser,
        isDevModeEnabled: settings.isDevModeEnabled,
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
    isSuperuser: (context) => Settings.readEnvironment(context).isSuperuser,
    homePath: WalletRoute.walletHome.path,
    onExit: (context) => context.goNamed(WalletRoute.walletHome.name),
    onOpenSettings: SettingsNavigation.open,
    onAction: (context, action) => switch (action) {
      ExchangeHomeAction.buy => context.pushNamed<void>(BuyRoute.buy.name),
      ExchangeHomeAction.sell => context.pushNamed<void>(SellRoute.sell.name),
      ExchangeHomeAction.pay => context.pushNamed<void>(PayRoute.pay.name),
      ExchangeHomeAction.transfer => SwapNavigation.open(context),
    },
  );

  static void _openQuickAction(BuildContext context, QuickAction action) {
    switch (action) {
      case QuickAction.toggleAmounts:
        Settings.toggleAmountVisibility(context);
      case QuickAction.map:
        context.pushNamed(BtcMapFeature.routeName);
      case QuickAction.transfer:
        SwapNavigation.open(context);
      case QuickAction.history:
        TransactionsNavigation.openHistory(context);
      case QuickAction.settings:
        SettingsNavigation.open(context);
      case QuickAction.support:
        Support.contactSupport(context);
      case QuickAction.priceHistory:
        BitcoinPriceFeature.openHistory(context);
      case QuickAction.pay:
        context.pushNamed(PayRoute.pay.name);
      case QuickAction.exchange:
        if (locator<ExchangeFacade>().currentAccess is ExchangeAccessDisabled) {
          unawaited(_activateExchange(context));
        } else {
          context.pushNamed(ExchangeRoute.exchangeHome.name);
        }
    }
  }

  static bool _activatingExchange = false;

  static Future<void> _activateExchange(BuildContext context) async {
    if (_activatingExchange) return;
    _activatingExchange = true;
    final Result<void, ExchangeFailure> result;
    try {
      result = await locator<ExchangeFacade>().enable();
    } finally {
      _activatingExchange = false;
    }
    if (!context.mounted) return;
    if (result case Err(:final failure)) {
      BullSnackBar.show(context, message: failure.toTranslated(context));
      return;
    }
    final signedIn = ExchangeAvailability.canManageAccount(
      locator<ExchangeFacade>().currentAccess,
    );
    if (signedIn) {
      context.pushNamed(ExchangeRoute.exchangeHome.name);
    } else {
      context.goNamed(ExchangeRoute.exchangeAuth.name);
    }
  }

  static final _exchangeFeature = ExchangeRouter.mount(
    _exchangeConfig,
    exchange: () => locator<Exchange>(),
    preferences: () => locator<Preferences>(),
    settings: SettingsRouter.exchangeSettingsHost,
    purchases: exchangePurchaseHost(locator),
    payins: exchangePayinHost(locator),
  );

  static void _onBackupTestSucceeded(BuildContext context) {
    WalletRecoverBullBindings.tested(context);
    router.goNamed(WalletRoute.walletHome.name);
  }

  static final _announcements = AnnouncementsFeature.mount(
    dismissals: locator<AnnouncementDismissals>(),
    isAppUpdateRequired: () => locator<OrderSwaps>().isAppUpdateRequired,
    watchAppUpdateRequired: () =>
        locator<OrderSwaps>().watchAppUpdateRequired(),
    openPayjoinSettings: (context) =>
        context.pushNamed(SettingsRoute.payjoinSettings.name),
  );

  static final _sendRoutes = SendFeature.mount(
    spend: locator<Spend>(),
    fees: locator<Fees>(),
    electrum: locator<Electrum>(),
    environment: locator<ActiveEnvironmentReader>(),
    goToWalletHome: (context) => context.goNamed(WalletRoute.walletHome.name),
    broadcastSuccessImage: AssetImage(Assets.animations.successTick.path),
    missingWalletRedirect: WalletRoute.walletHome.path,
    selectBalanceSat: WalletConsolidation.selectBalanceSat,
  );

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    onEnter: ExchangeTradingGuard(
      navigatorKey: rootNavigatorKey,
      checkAvailability: locator<ExchangeFacade>().guardTradingEntry,
      resolveAccess: locator<ExchangeFacade>().resolveAccess,
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
                appBar: tabIndex == 0 ? const WalletHomeAppBar() : null,
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
            exchangePrompt: locator<ExchangePromptCubit>(),
            onActivateExchange: _activateExchange,
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
      locator<OnboardingFeature>().route,
      ...locator<AccessFeature>().routes.root,
      WalletRouter.walletDetailRoute(
        scopeWalletHistory: locator<TransactionsFeature>().scopeWalletHistory,
        loadCoinSummary: (id) => locator<Coins>().summary(id),
        onOpenCoins: CoinsNavigation.open,
      ),
      _sendRoutes.consolidation,
      SettingsFeature.mount(
        menuScope: SettingsRouter.menuScope,
        settings: locator.call<Settings>,
        appSettingsRoutes: locator<NetworkFeature>().routes.appSettings,
        status: locator<NetworkFeature>().status,
        childRoutes: SettingsRouter.childRoutes(
          autoswapSettingsRoute: locator<SwapFeature>().autoswapSettingsRoute,
          addressRoutes: [locator<AddressViewFeature>().route],
          accessRoutes: locator<AccessFeature>().routes.settings,
          seedViewRoute: locator<AllSeedViewFeature>().route,
          exchangeSettingsRoutes: _exchangeFeature.settingsRoutes,
          backupRoutes: [
            BackupsFeature.mount(
              secrets: () => locator<Secrets>(),
              inventory: () => locator<SecretsInventory>(),
              environment: () => locator<ActiveEnvironmentReader>(),
              records: (network) => locator<RecoverBullWalletBackups>(
                instanceName: network.env == NetworkEnv.regtest
                    ? 'regtest'
                    : null,
              ),
              vaultStatus: (context) =>
                  locator<RecoverBullFacade>().status(context),
              encryptedIcon: Image.asset(
                Assets.misc.encryptedVault.path,
                fit: .contain,
              ),
              physicalIcon: Image.asset(
                Assets.misc.physicalBackup.path,
                fit: .contain,
              ),
              successImage: AssetImage(Assets.animations.successTick.path),
              onTestSucceeded: _onBackupTestSucceeded,
              onExportTransactions: TransactionsNavigation.openExport,
            ).route,
          ],
          priceRoutes: locator<BitcoinPriceFeature>().routes,
        ),
      ).route,
      ...locator<TransactionsFeature>().routes,
      locator<ReceiveFeature>().route,
      SendRouter.route(
        locator: locator,
        openSignedTransactionReader: BroadcastSignedTxRoute.readForSend,
      ),
      locator<CoinsFeature>().route,
      ...locator<SwapFeature>().routes,
      ..._exchangeFeature.buyRoutes,
      ..._exchangeFeature.fundingRoutes,
      ?_exchangeFeature.sellRoute,
      ?_exchangeFeature.withdrawalRoute,
      ?_exchangeFeature.payRoute,
      _sendRoutes.broadcastSignedTx,
      ...locator<SignersFeature>().routes,
      ?_exchangeFeature.dcaRoute,
      ?_exchangeFeature.autoBuy,
      ?_exchangeFeature.limitOrderCreate,
      ?_exchangeFeature.limitOrderDetails,
      _sendRoutes.replaceByFee,
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
