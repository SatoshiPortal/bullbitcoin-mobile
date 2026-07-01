import 'package:bb_mobile/core/themes/colors.dart';
import 'package:bb_mobile/core/widgets/bb_pullable_body.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/auto_swap_fee_warning.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/autoswap_warning_bottom_sheet.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/home_errors.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_bottom_buttons.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_cards.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_home_top_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  bool _hasShownAutoSwapWarning = false;
  // ensures that the warning is only showed once on app startup

  final GlobalKey<RefreshIndicatorState> _indicatorKey =
      GlobalKey<RefreshIndicatorState>();

  GoRouter? _router;

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
      _refreshOnVisible();
      // If a refresh was already in flight before this mount (e.g. the
      // post-startup WalletStarted refresh), show the spinner over it so the
      // user sees activity instead of landing on apparently-static data.
      if (context.read<WalletBloc>().state.isRefreshing) {
        _indicatorKey.currentState?.show();
      }
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
    final location = _router?.routerDelegate.currentConfiguration.uri.path;
    if (location == WalletRoute.walletHome.path) _refreshOnVisible();
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _refreshOnVisible() {
    if (!mounted) return;
    context.read<WalletBloc>().add(const WalletRefreshed());
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<WalletBloc, WalletState>(
          listenWhen: (previous, current) =>
              !previous.isRefreshing && current.isRefreshing,
          listener: (context, state) {
            // A refresh just started (manual pull, post-activity dispatch,
            // env change, etc.) — surface the spinner. RefreshIndicator.show()
            // is a no-op if it's already running, so this is safe to combine
            // with the initState path.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _indicatorKey.currentState?.show();
            });
          },
        ),
        BlocListener<WalletBloc, WalletState>(
          listenWhen: (previous, current) =>
              previous.autoSwapSettings != current.autoSwapSettings ||
              previous.wallets != current.wallets,
          listener: (context, state) {
            if (!_hasShownAutoSwapWarning &&
                state.showAutoSwapDefaultEnabledWarning()) {
              _hasShownAutoSwapWarning = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                AutoSwapWarningBottomSheet.show(context);
              });
            }
          },
        ),
      ],
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {},
        child: Stack(
          children: [
            // Black background visible only during iOS top overscroll
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ColoredBox(
                color: AppColors.dark.background,
                child: const SizedBox(height: 300),
              ),
            ),
            BBPullableBody(
              indicatorKey: _indicatorKey,
              onRefresh: () => context.read<WalletBloc>().refresh(),
              slivers: [
                const SliverToBoxAdapter(child: WalletHomeTopSection()),
                const SliverToBoxAdapter(child: HomeWarnings()),
                const SliverToBoxAdapter(child: AutoSwapFeeWarning()),
                SliverToBoxAdapter(
                  child: WalletCards(
                    onTap: (w) {
                      context.pushNamed(
                        WalletRoute.walletDetail.name,
                        pathParameters: {'walletId': w.id},
                      );
                    },
                  ),
                ),
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
                  child: WalletBottomButtons(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
