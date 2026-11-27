import 'dart:async';

import 'package:address_view/address_view.dart' show AddressView;
import 'package:address_view/routes.dart';
import 'package:all_seed_view/setup.dart' show AllSeedViewFeature;
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:bull_ark/bull_ark.dart' show ArkAccountsFacade;
import 'package:receive/receive.dart' show Receive;
import 'package:secrets/custody.dart' show SeedReferences;
import 'package:signers/storage.dart' show SignerDevices;
import 'package:silent/silent.dart' show Silent;
import 'package:swaps/swaps.dart' show SwapStore, Swaps;
import 'package:sync/sync.dart' show WalletKey, WalletCatalogPort;
import 'package:sync/write.dart'
    show ElectrumSync, ForegroundWalletSynchronization, WalletNativeRuntime;
import 'package:transactions/transactions.dart' show Transactions;
import 'package:primitives/primitives.dart' show Err, NetworkEnv, Result;
import 'package:secrets/storage.dart';
import 'package:secrets/secrets.dart';
import 'package:backup_metadata/setup.dart' show BackupMetadataFeature;
import 'package:backups/backups.dart';
import 'package:bull_recoverbull/storage.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_ark/ark_ui_setup.dart';
import 'package:bull_exchange/bull_exchange.dart'
    show
        BullExchangeFeature,
        BullExchangeNavigation,
        BuyRoute,
        ExchangeFailureL10n,
        ExchangeGuardedPaths,
        ExchangeHomeAction,
        ExchangeSettingsHost,
        ExchangeSessionScope,
        ExchangeRouteGuard,
        PayRoute,
        SellRoute;
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_cards.dart';
import 'package:bitcoin_price/bitcoin_price.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullSnackBar, BullSpacing, BullThemeX;
import 'package:settings/settings.dart';
import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_quick_actions/setup.dart';
import 'package:bull_logs/bull_logs.dart';
import 'package:btc_map/btc_map.dart';
import 'package:provisioning/provisioning.dart' show NetworkWalletProvisioning;

import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:startup/startup.dart' show RouteErrorScreen;
import 'package:announcements/setup.dart';
import 'package:views/setup.dart' show ViewsFeature;
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
    show OrderSwapUnderReviewCard, SwapFeature, SwapNavigation;
import 'package:wallet_import/setup.dart';
import 'package:onboarding/setup.dart';
import 'package:receive/setup.dart' show ReceiveFeature;
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:silent/setup.dart';
import 'package:transactions/routes.dart';
import 'package:overview/setup.dart' show OverviewSynchronization;
import 'package:bull_payjoin/bull_payjoin.dart'
    show
        Payjoin,
        PayjoinPolicyAccess,
        PayjoinReceiver,
        PayjoinSender,
        PayjoinSessions;
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_consolidation.dart';
import 'package:overview/overview.dart'
    show EyeToggle, SilentWalletBalance, WalletHomeAppBar;
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
  static PreferredSizeWidget walletHomeAppBar() => WalletHomeAppBar(
    title: SuperuserTapUnlocker(
      child: SizedBox.square(
        dimension: BullSpacing.xxl,
        child: Center(
          child: Assets.logos.bbLogoSmall.image(width: 40, height: 40),
        ),
      ),
    ),
  );

  static Widget withBackupWarning(Widget child) =>
      BlocSelector<WalletBloc, WalletState, bool>(
        selector: (state) => state.showBackupWarning(),
        builder: (context, showWarning) => BackupWarningOverlay(
          showWarning: showWarning,
          onWarningShown: () =>
              context.read<WalletBloc>().add(const VerifyBackupStatus()),
          onDismiss: () =>
              context.read<WalletBloc>().add(const DismissBackupWarning()),
          child: child,
        ),
      );

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
    openSend: SendNavigation.openSilent,
    balanceBuilder: (context, balanceSat) => SilentWalletBalance(
      background: AssetImage(Assets.backgrounds.bgSecureWallet.path),
      balanceSat: balanceSat,
      eyeToggle: Builder(
        builder: (context) => EyeToggle(
          hideAmounts: context.select(
            (WalletBloc bloc) => bloc.state.amountDisplay?.hideAmounts,
          ),
          showLabel: context.loc.walletShowAmountsTooltip,
          hideLabel: context.loc.walletHideAmountsTooltip,
          onChanged: (hide) => Settings.setAmountsHidden(context, hide),
        ),
      ),
      fiatBalance: HomeFiatBalance(
        balanceSat: balanceSat,
        onCurrencyChanged: Settings.changeDisplayCurrency,
      ),
    ),
    settingsIconBuilder: (context) => Image.asset(
      Assets.icons.settingsLine.path,
      width: 24,
      height: 24,
      color: context.bull.onSurface,
    ),
  );
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'rootNav');

  static final exchangeSettingsHost = ExchangeSettingsHost(
    networkOf: Settings.networkOf,
    isSuperuser: Settings.isSuperuserOf,
    title: (context) => context.loc.settingsExchangeSettingsTitle,
    signedOutMessage: (context) => context.loc.notLoggedInMessage,
    accessDescription: (context) =>
        context.loc.exchangeAccessSettingsDescription,
    onOpenRecipients: (context) => context.pushNamed(PayRoute.pay.name),
    onOpenTransactions: (context) =>
        TransactionsNavigation.openHistory(context, exchangeOnly: true),
    includeDefaultWallets: true,
  );

  static void exitExchange(BuildContext context) =>
      context.goNamed(WalletRoute.walletHome.name);

  static void customizeQuickActions(BuildContext context) =>
      context.pushNamed(SettingsRoute.quickActions.name);

  static List<RouteBase> settingsChildren({
    required List<RouteBase> priceRoutes,
    required QuickActionsCubit Function() quickActions,
    required List<RouteBase> exchangeSettingsRoutes,
    required List<RouteBase> swapRecoveryRoutes,
    RouteBase? autoswapSettingsRoute,
    required List<RouteBase> accessRoutes,
    required List<RouteBase> backupRoutes,
    required List<RouteBase> walletRoutes,
    List<RouteBase> addressRoutes = const [],
    RouteBase? seedViewRoute,
  }) => [
    ...priceRoutes,
    GoRoute(
      name: SettingsRoute.quickActions.name,
      path: SettingsRoute.quickActions.path,
      builder: (_, _) => QuickActionsCustomizationScreen(cubit: quickActions()),
    ),
    ...exchangeSettingsRoutes,
    ...swapRecoveryRoutes,
    ?autoswapSettingsRoute,
    ...accessRoutes,
    ...backupRoutes,
    ...walletRoutes,
    ...addressRoutes,
    const LogsFeature().route,
    ?seedViewRoute,
  ];

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
        if (locator<Exchange>().currentAccess is ExchangeAccessDisabled) {
          unawaited(_activateExchange(context));
        } else {
          context.pushNamed(BullExchangeNavigation.dashboardName);
        }
    }
  }

  static bool _activatingExchange = false;

  static Future<void> _activateExchange(BuildContext context) async {
    if (_activatingExchange) return;
    _activatingExchange = true;
    final Result<void, ExchangeFailure> result;
    try {
      result = await locator<Exchange>().enableAccess();
    } finally {
      _activatingExchange = false;
    }
    if (!context.mounted) return;
    if (result case Err(:final failure)) {
      BullSnackBar.show(context, message: failure.toTranslated(context));
      return;
    }
    final signedIn = ExchangeAvailability.canManageAccount(
      locator<Exchange>().currentAccess,
    );
    if (signedIn) {
      context.pushNamed(BullExchangeNavigation.dashboardName);
    } else {
      context.goNamed(BullExchangeNavigation.authName);
    }
  }

  static final _exchangeFeature = BullExchangeFeature.mount(
    exchange: () => locator<Exchange>(),
    preferences: () => locator<Preferences>(),
    isSuperuser: (context) => Settings.readEnvironment(context).isSuperuser,
    homePath: WalletRoute.walletHome.path,
    onExit: exitExchange,
    onOpenSettings: SettingsNavigation.open,
    onAction: (context, action) => switch (action) {
      ExchangeHomeAction.buy => context.pushNamed<void>(BuyRoute.buy.name),
      ExchangeHomeAction.sell => context.pushNamed<void>(SellRoute.sell.name),
      ExchangeHomeAction.pay => context.pushNamed<void>(PayRoute.pay.name),
      ExchangeHomeAction.transfer => SwapNavigation.open(context),
    },
    brandAssetPath: Assets.logos.bbLogoSmall.path,
    settingsAssetPath: Assets.icons.settingsLine.path,
    settings: exchangeSettingsHost,
    purchases: (
      displayPreferences: () => locator<AmountDisplayPreferencesReader>(),
      inventory: () => locator<SecretsInventory>(),
      native: () => locator<WalletNativeRuntime>(),
      fees: () => locator<Fees>(),
      payjoinSessions: () => locator<PayjoinSessions>(),
      payjoinReceiver: () => locator<PayjoinReceiver>(),
      payjoinPolicy: () => locator<PayjoinPolicyAccess>(),
      pollWallet: (id) => locator<OverviewSynchronization>().coordinator
          .pollWallet(id, isActive: () => true),
      transactions: () => locator<Transactions>(),
      bitcoinAsset: Assets.icons.btc.path,
      onClose: (context) => context.goNamed(WalletRoute.walletHome.name),
    ),
    payins: (
      exchange: () => locator<Exchange>(),
      preferences: () => locator<Preferences>(),
      inventory: () => locator<SecretsInventory>(),
      native: () => locator<WalletNativeRuntime>(),
      spend: () => locator<Spend>(),
      fees: () => locator<Fees>(),
      payjoinPolicy: () => locator<PayjoinPolicyAccess>(),
      payjoinSender: () => locator<PayjoinSender>(),
      payjoinSessions: () => locator<PayjoinSessions>(),
      labels: () => locator<Labels>(),
      ui: (
        walletCards: WalletCards.pickLocalSigner,
        openWalletHome: exitExchange,
        brandAsset: Assets.logos.bbLogoSmall.path,
        successAsset: Assets.animations.successTick.path,
      ),
    ),
  );

  static void _onBackupTestSucceeded(BuildContext context) {
    context.read<WalletBloc>().add(const VerifyBackupStatus());
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
    payment: () => (
      inventory: locator<SecretsInventory>(),
      native: locator<WalletNativeRuntime>(),
      synchronize: (key) => locator<ForegroundWalletSynchronization>()
          .executeKey(key, locator<WalletCatalogPort>()),
      finishedSyncs: locator<ElectrumSync>().finished.map((event) => event.key),
      readSignerDevice: (walletId) => locator<SignerDevices>().read(walletId),
      preferences: locator<Preferences>(),
      coins: locator<Coins>(),
      addresses: locator<AddressView>(),
      receive: locator<Receive>(),
      swaps: locator<Swaps>(),
      orders: locator<OrderSwaps>(),
      payjoin: locator<Payjoin>(),
      transactions: locator<Transactions>(),
      labels: locator<Labels>(),
      silent: locator<Silent>(),
    ),
    arkAccounts: () => locator.isRegistered<ArkAccountsFacade>()
        ? locator<ArkAccountsFacade>()
        : null,
    openCoins: CoinsNavigation.replace,
    orderUnderReview: (order) => OrderSwapUnderReviewCard(orderSwap: order),
    pollSettlement: (id, {required isActive}) =>
        locator<OverviewSynchronization>().coordinator.pollWallet(
          id,
          isActive: isActive,
        ),
  );

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    onEnter: ExchangeRouteGuard(
      navigatorKey: rootNavigatorKey,
      checkAvailability: locator<Exchange>().guardTradingEntry,
      resolveAccess: locator<Exchange>().resolveAccess,
      // The exchange settings routes are nested under the settings hub below.
      paths:
          ExchangeGuardedPaths.mounted +
          ExchangeGuardedPaths.settingsUnder(SettingsNavigation.homePath),
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
          final tabIndex =
              location.startsWith(BullExchangeNavigation.dashboardPath) ? 1 : 0;

          final shell = PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              context.goNamed(WalletRoute.walletHome.name);
            },
            child: withBackupWarning(
              Scaffold(
                // The app bar of the exchange tab is rendered by the
                // ExchangeHomeScreen itself, as an overlay.
                appBar: tabIndex == 0 ? walletHomeAppBar() : null,
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
            quickActions: () => locator<QuickActionsFeature>().quickActions,
            onQuickAction: _openQuickAction,
            onCustomizeQuickActions: customizeQuickActions,
            exchangePrompt: () => locator<QuickActionsFeature>().exchangePrompt,
            onActivateExchange: _activateExchange,
            watchUnreadSupportMessages:
                ExchangeSessionScope.watchUnreadSupportMessages,
            networkWalletProvisioning: locator.call<NetworkWalletProvisioning>,
            announcements: () => _announcements.carousel(),
          ),
          ?_exchangeFeature.dashboardRoute,
          ..._exchangeFeature.routes,
        ],
      ),
      ?_exchangeFeature.authRoute,
      ?_exchangeFeature.supportChatRoute,
      locator<OnboardingFeature>().route,
      ...locator<AccessFeature>().routes.root,
      ...locator<ViewsFeature>().routes,
      WalletRouter.walletDetailRoute(
        scopeWalletHistory: locator<TransactionsFeature>().scopeWalletHistory,
        loadCoinSummary: (id) => locator<Coins>().summary(id),
        onOpenCoins: (context, wallet) => CoinsNavigation.open(
          context,
          WalletKey(id: wallet.id, network: wallet.network.shared),
        ),
      ),
      _sendRoutes.consolidation,
      SettingsFeature.mount(
        exchange: locator.call<Exchange>,
        settings: locator.call<Settings>,
        appSettingsRoutes: locator<NetworkFeature>().routes.appSettings,
        status: locator<NetworkFeature>().status,
        childRoutes: settingsChildren(
          quickActions: () => locator<QuickActionsFeature>().quickActions,
          swapRecoveryRoutes: locator<SwapFeature>().recoveryRoutes,
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
              dataBackup: locator.isRegistered<BackupMetadataFeature>()
                  ? (context) => locator<BackupMetadataFeature>().page(
                      onClose: () => context.pop(),
                    )
                  : null,
              dataBackupStatus: locator.isRegistered<BackupMetadataFeature>()
                  ? locator<BackupMetadataFeature>().statusLabel
                  : null,
              dataBackupChanges: locator.isRegistered<BackupMetadataFeature>()
                  ? locator<BackupMetadataFeature>().summary
                  : null,
            ).route,
          ],
          priceRoutes: locator<BitcoinPriceFeature>().routes,
          walletRoutes: [
            SettingsFeature.walletDetails(
              inventory: locator<SecretsInventory>(),
              devices: locator<SignerDevices>(),
              native: locator<WalletNativeRuntime>(),
              swaps: locator<SwapStore>(),
              orders: locator<OrderSwaps>(),
              references: locator<SeedReferences>(),
              secrets: locator<Secrets>(),
              discover: (walletId) => locator<OverviewSynchronization>()
                  .coordinator
                  .discoverWallet(walletId),
              onDeleted: (context) {
                context.read<WalletBloc>().add(const WalletStarted());
                context.goNamed(WalletRoute.walletHome.name);
              },
            ),
          ],
        ),
      ).route,
      ...locator<TransactionsFeature>().routes,
      locator<ReceiveFeature>().route,
      _sendRoutes.payment,
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
          context.read<WalletBloc>().add(const WalletStarted());
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
