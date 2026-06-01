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
import 'package:bb_mobile/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> with RouteAware {
  bool _hasShownAutoSwapWarning = false;
  // ensures that the warning is only showed once on app startup

  final GlobalKey<RefreshIndicatorState> _indicatorKey =
      GlobalKey<RefreshIndicatorState>();

  ModalRoute<void>? _subscribedRoute;

  @override
  void initState() {
    super.initState();
    // If a refresh is already in flight when WalletHome mounts (cold boot,
    // post-import, post-PIN unlock, etc.), show the spinner over it so the
    // user sees the activity instead of landing on apparently-static data.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<WalletBloc>().state.isRefreshing) {
        _indicatorKey.currentState?.show();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route push/pop events so any navigation that lands on
    // this screen — initial push, or pop returning here from a pushed
    // sub-route — fires a throttled `WalletRefreshed`. The coordinator
    // skips redundant work; the threshold lives there, not here.
    final route = ModalRoute.of(context);
    if (route != _subscribedRoute) {
      if (_subscribedRoute != null) {
        AppRouter.routeObserver.unsubscribe(this);
      }
      _subscribedRoute = route;
      if (route != null) {
        AppRouter.routeObserver.subscribe(this, route);
      }
    }
  }

  @override
  void dispose() {
    AppRouter.routeObserver.unsubscribe(this);
    super.dispose();
  }

  void _refreshOnVisible() {
    if (!mounted) return;
    context.read<WalletBloc>().add(const WalletRefreshed());
  }

  @override
  void didPush() => _refreshOnVisible();

  @override
  void didPopNext() => _refreshOnVisible();

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
              onRefresh: () async {
                // User gesture — bypass the coordinator throttle.
                final bloc = context.read<WalletBloc>();
                bloc.add(const WalletRefreshed(force: true));
                await bloc.stream.firstWhere((state) => !state.isRefreshing);
              },
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
