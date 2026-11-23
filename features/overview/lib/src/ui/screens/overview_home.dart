import 'dart:async';

import 'package:bitcoin_price/bitcoin_price.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../widgets/wallet_refresh_body.dart';

class OverviewHome extends StatefulWidget {
  final String homePath;
  final Widget? empty;
  final bool isRefreshing;
  final VoidCallback refreshVisibleWallets;
  final Future<void> Function() waitForRefresh;
  final Future<void> Function() refreshWallets;
  final double headerBackgroundHeight;
  final Widget header;
  final Widget announcements;
  final Widget warnings;
  final Widget consolidation;
  final Widget wallets;
  final Widget Function(int refresh) ark;
  final Widget bottomActions;

  const OverviewHome({
    super.key,
    required this.homePath,
    required this.empty,
    required this.isRefreshing,
    required this.refreshVisibleWallets,
    required this.waitForRefresh,
    required this.refreshWallets,
    required this.headerBackgroundHeight,
    required this.header,
    required this.announcements,
    required this.warnings,
    required this.consolidation,
    required this.wallets,
    required this.ark,
    required this.bottomActions,
  });

  @override
  State<OverviewHome> createState() => _OverviewHomeState();
}

class _OverviewHomeState extends State<OverviewHome> {
  /// Height the pinned Receive/Send bar occupies
  static const double _bottomBarHeight = 52.0 + 16.0 * 2;

  GoRouter? _router;
  bool _homeVisible = false;
  int _arkRefresh = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // #2222: a fresh mount triggers a sync — covers cold boot and switching
      // back to the wallet tab (the shell rebuilds its child on switch, so this
      // screen remounts). The pop-back-to-home path, where this screen stays
      // mounted, is handled by the router listener below. The coordinator
      // throttles, so a redundant trigger is cheap.
      _onRouteChanged();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // #2222: sync whenever navigation lands back on the wallet home — e.g.
    // popping a pushed full-screen route (send/receive/settings) where this
    // screen stayed mounted beneath it. A RouteObserver can't see those pops:
    // home lives inside the tab shell while those routes are pushed on the root
    // navigator, so the pop reveals the *shell*, not home. The router's own
    // current location is the reliable signal across that boundary.
    final router = GoRouter.of(context);
    if (!identical(router, _router)) {
      _router?.routerDelegate.removeListener(_onRouteChanged);
      _router = router;
      router.routerDelegate.addListener(_onRouteChanged);
    }
  }

  void _onRouteChanged() {
    if (!mounted) return;
    final configuration = _router?.routerDelegate.currentConfiguration;
    final top = configuration?.lastOrNull;
    // A push keeps the base URI (/wallet). Its imperative match owns the
    // visible location, including Receive on the root navigator.
    final location = top is ImperativeRouteMatch
        ? top.matches.uri.path
        : configuration?.uri.path;
    final visible = location == widget.homePath;
    final becameVisible = visible && !_homeVisible;
    _homeVisible = visible;
    if (becameVisible) _refreshOnVisible();
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _refreshOnVisible() {
    if (!mounted) return;
    setState(() => ++_arkRefresh);
    widget.refreshVisibleWallets();
    unawaited(BitcoinPriceFeature.refresh(context, onlyIfUnavailable: true));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.empty case final empty?) return empty;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {},
      child: Stack(
        children: [
          // Match the header backdrop during iOS top overscroll.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ColoredBox(
              color: context.appColors.homeHeaderBackground,
              child: SizedBox(height: widget.headerBackgroundHeight),
            ),
          ),
          WalletRefreshBody(
            isRefreshing: widget.isRefreshing,
            waitForRefresh: widget.waitForRefresh,
            onRefresh: () {
              setState(() => ++_arkRefresh);
              unawaited(BitcoinPriceFeature.refresh(context));
              return widget.refreshWallets();
            },
            bottomInset:
                _bottomBarHeight + MediaQuery.paddingOf(context).bottom,
            slivers: [
              PinnedHeaderSliver(child: widget.header),
              SliverToBoxAdapter(child: widget.announcements),
              SliverToBoxAdapter(child: widget.warnings),
              SliverToBoxAdapter(child: widget.consolidation),
              SliverToBoxAdapter(child: widget.wallets),
              SliverToBoxAdapter(child: widget.ark(_arkRefresh)),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13.0,
                  vertical: 16.0,
                ),
                child: widget.bottomActions,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
