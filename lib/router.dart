import 'package:bb_mobile/features/wallet/presentation/network_wallet_setup_cubit.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:primitives/primitives.dart' show NetworkCapability;

import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/screens/route_error_screen.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
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
import 'package:bb_mobile/core/widgets/navbar/top_bar_bull_logo.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullBreakpoints,
        BullLayoutX,
        BullSideNav,
        BullSideNavItem,
        BullSupportScope;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// The main router of the app. It is the root of the routing tree and contains
/// all the entry-level routes.
class AppRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'rootNav');

  static final _modalObserver = _ModalObserver();

  static final _exchangeConfig = ExchangeRouterConfig(
    networkUnavailable: () => locator<ExchangeFacade>().networkUnavailable(),
    isSuperuser: (context) =>
        context.read<SettingsCubit>().state.isSuperuser ?? false,
    homePath: WalletRoute.walletHome.path,
    buildHomeCards: () => [locator<LimitOrdersFacade>().buildDashboardCard()],
    onHomeRefresh: () => locator<LimitOrdersFacade>().refreshDashboard(),
    onExit: (context) => context.goNamed(WalletRoute.walletHome.name),
    onOpenSettings: (context) => context.pushNamed(SettingsRoute.settings.name),
  );

  static final GoRouter router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: WalletRoute.walletHome.path,
    // Breadcrumbs only — `enableAutoTransactions: false` skips the
    // performance/TTID instrumentation so we stay within the
    // error-reporting scope (consent-gated) rather than perf tracing.
    observers: [
      SentryNavigatorObserver(enableAutoTransactions: false),
      _modalObserver,
    ],
    redirect: (BuildContext context, GoRouterState state) {
      final path = state.uri.path;
      // Only read the gate providers for SP routes; the decision itself lives
      // in the SP feature's pure `spRedirect` (unit-testable, no widget tree).
      if (!isSpPath(path)) return null;
      final settingsState = context.read<SettingsCubit>().state;
      return spRedirect(
        path,
        environment: settingsState.environment?.networkEnv,
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
        pageBuilder: (context, state, child) {
          final location = state.uri.toString();
          final tabIndex = location.startsWith(ExchangeRoute.exchangeHome.path)
              ? 1
              : 0;

          return NoTransitionPage(
            key: state.pageKey,
            child: MultiBlocProvider(
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
                  child: context.isDesktopLayout
                      ? _DesktopShell(location: location, child: child)
                      : _MobileShell(tabIndex: tabIndex, child: child),
                ),
              ),
            ),
          );
        },
        routes: [
          WalletRouter.walletHomeRoute(
            createSetupCubit: () => locator<NetworkWalletSetupCubit>(),
            desktop: WalletHomeDesktopConfig(
              buildActions: (context) => [
                WalletHomeDesktopAction(
                  icon: Icons.currency_bitcoin,
                  label: context.loc.homeActionBuy,
                  onTap: () => context.pushNamed(BuyRoute.buy.name),
                ),
                WalletHomeDesktopAction(
                  icon: Icons.attach_money,
                  label: context.loc.homeActionSell,
                  onTap: () => context.pushNamed(SellRoute.sell.name),
                ),
                WalletHomeDesktopAction(
                  icon: Icons.payments_outlined,
                  label: context.loc.homeActionPay,
                  onTap: () => ExchangeScope.isLoggedIn(context)
                      ? context.pushNamed(PayRoute.pay.name)
                      : context.goNamed(ExchangeRoute.exchangeLanding.name),
                ),
                WalletHomeDesktopAction(
                  icon: Icons.swap_horiz,
                  label: context.loc.homeActionTransfer,
                  onTap: () => context.pushNamed(SwapRoute.swap.name),
                ),
              ],
              buildExchangePanel: (_) => ExchangeRouter.homeDesktopPanel(),
              buildRecentTransactions: (_) =>
                  TransactionsRouter.recentTransactionsPanel(
                    scope: (child) => ActiveNetworkScope(child: child),
                  ),
              onOpenTransactions: (context) =>
                  context.pushNamed(TransactionsRoute.transactions.name),
            ),
          ),
          ...ExchangeRouter.routes(_exchangeConfig),
        ],
      ),
      ExchangeRouter.supportChatRoute(_exchangeConfig),
      OnboardingRouter.route,
      AppUnlockRouter.route,
      WalletRouter.walletDetailRoute(
        onOpenCoins: (context, wallet) =>
            context.pushNamed<void>(CoinsRoute.coins.name, extra: wallet),
      ),
      ConsolidationRouter.route,
      SettingsRouter.route,
      TransactionsRouter.transactionsRoute(
        scope: (child) => ActiveNetworkScope(child: child),
      ),
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

class _MobileShell extends StatelessWidget {
  const _MobileShell({required this.tabIndex, required this.child});

  final int tabIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The app bar of the exchange tab is rendered by the
      // ExchangeHomeScreen itself, as an overlay.
      appBar: tabIndex == 0 ? const WalletHomeAppBar() : null,
      extendBodyBehindAppBar: true,
      body: child,
      bottomNavigationBar: NetworkCapabilityVisibility(
        capability: NetworkCapability.exchange,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BottomNavigationBar(
              currentIndex: tabIndex,
              onTap: (index) {
                if (index == 0) {
                  context.goNamed(WalletRoute.walletHome.name);
                } else {
                  // Exchange tab
                  if (Platform.isIOS) {
                    final isSuperuser =
                        context.read<SettingsCubit>().state.isSuperuser ??
                        false;
                    if (isSuperuser) {
                      context.goNamed(ExchangeRoute.exchangeHome.name);
                    } else {
                      context.goNamed(ExchangeRoute.exchangeLanding.name);
                    }
                  } else {
                    context.goNamed(ExchangeRoute.exchangeHome.name);
                  }
                }
              },
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.currency_bitcoin),
                  label: context.loc.navigationTabWallet,
                  backgroundColor: context.appColors.background,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.attach_money),
                  label: context.loc.navigationTabExchange,
                  backgroundColor: context.appColors.background,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isHome = location.startsWith(WalletRoute.walletHome.path);
    return Scaffold(
      body: isHome
          ? child
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: BullBreakpoints.pageMaxWidth,
                ),
                child: child,
              ),
            ),
    );
  }
}

class _ModalObserver extends NavigatorObserver {
  final ValueNotifier<int> depth = ValueNotifier(0);

  void _change(Route<dynamic> route, int delta) {
    if (route is! PopupRoute) return;
    scheduleMicrotask(() => depth.value += delta);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(route, 1);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(route, -1);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(route, -1);
}

/// Keeps the side navigation next to every page on a desktop window.
///
/// It sits above the navigator, so a pushed page opens in the content area and
/// the navigation stays in place.
class AppDesktopFrame extends StatefulWidget {
  const AppDesktopFrame({super.key, required this.child});

  final Widget child;

  @override
  State<AppDesktopFrame> createState() => _AppDesktopFrameState();
}

class _AppDesktopFrameState extends State<AppDesktopFrame> {
  static const _withoutNavigation = ['/onboarding', '/app-unlock'];

  String _location = '';

  @override
  void initState() {
    super.initState();
    AppRouter.router.routerDelegate.addListener(_onRouteChanged);
    _location = _currentLocation();
  }

  @override
  void dispose() {
    AppRouter.router.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  String _currentLocation() {
    final configuration = AppRouter.router.routerDelegate.currentConfiguration;
    final top = configuration.lastOrNull;
    return top is ImperativeRouteMatch
        ? top.matches.uri.path
        : configuration.uri.path;
  }

  void _onRouteChanged() {
    scheduleMicrotask(() {
      if (!mounted) return;
      final location = _currentLocation();
      if (location != _location) setState(() => _location = location);
    });
  }

  void _openFromHome(String routeName) {
    AppRouter.router.goNamed(WalletRoute.walletHome.name);
    AppRouter.router.pushNamed(routeName);
  }

  @override
  Widget build(BuildContext context) {
    final hidden =
        _location.isEmpty || _withoutNavigation.any(_location.startsWith);
    if (!context.isDesktopLayout || hidden) return widget.child;

    final onExchange = _location.startsWith(ExchangeRoute.exchangeHome.path);
    final onTransactions = _location.startsWith('/transaction');
    final onSettings = _location.startsWith(SettingsRoute.settings.path);
    final onHome =
        !onExchange &&
        !onTransactions &&
        !onSettings &&
        _location.startsWith(WalletRoute.walletHome.path);

    final navigation = NetworkCapabilityBuilder(
      capability: NetworkCapability.exchange,
      builder: (context, exchangeSupported) => BullSideNav(
        header: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TopBarBullLogo(enableSuperuserTapUnlocker: true),
            const SizedBox(width: 12),
            Text(
              context.loc.onboardingBullBitcoin,
              style: context.font.titleMedium?.copyWith(
                color: context.appColors.onSecondaryFixed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        items: [
          BullSideNavItem(
            icon: Icons.home_outlined,
            label: context.loc.navigationHome,
            selected: onHome,
            onTap: () => AppRouter.router.goNamed(WalletRoute.walletHome.name),
          ),
          if (exchangeSupported)
            BullSideNavItem(
              icon: Icons.attach_money,
              label: context.loc.navigationTabExchange,
              selected: onExchange,
              onTap: () => AppRouter.router.goNamed(
                ExchangeScope.isLoggedIn(context)
                    ? ExchangeRoute.exchangeHome.name
                    : ExchangeRoute.exchangeLanding.name,
              ),
            ),
          BullSideNavItem(
            icon: Icons.history,
            label: context.loc.transactionTitle,
            selected: onTransactions,
            onTap: () => _openFromHome(TransactionsRoute.transactions.name),
          ),
        ],
        footerItems: [
          BullSideNavItem(
            icon: Icons.chat_bubble_outline,
            label: context.loc.exchangeSupportChatTitle,
            onTap: () {
              final navigatorContext =
                  AppRouter.rootNavigatorKey.currentContext;
              if (navigatorContext == null) return;
              BullSupportScope.maybeOf(context)
                  ?.onContactSupport(navigatorContext);
            },
          ),
          BullSideNavItem(
            icon: Icons.settings_outlined,
            label: context.loc.settingsScreenTitle,
            selected: onSettings,
            onTap: () => _openFromHome(SettingsRoute.settings.name),
          ),
        ],
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueListenableBuilder(
          valueListenable: AppRouter._modalObserver.depth,
          builder: (context, depth, child) => IgnorePointer(
            ignoring: depth > 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: depth > 0 ? 0.4 : 1,
              child: child,
            ),
          ),
          child: navigation,
        ),
        Expanded(child: ClipRect(child: widget.child)),
      ],
    );
  }
}
