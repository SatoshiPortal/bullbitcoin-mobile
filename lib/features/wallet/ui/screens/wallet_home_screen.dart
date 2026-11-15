import 'package:bb_mobile/features/wallet/presentation/network_wallet_setup_cubit.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/empty_network_wallets.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/screens/wallet_home_desktop_body.dart';
import 'package:bb_mobile/features/wallet/ui/screens/wallet_home_mobile_body.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bull_ui/bull_ui.dart' show BullLayoutX;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class WalletHomeScreen extends StatefulWidget {
  final NetworkWalletSetupCubit Function() createSetupCubit;
  final VoidCallback onEmptyMainnet;
  final VoidCallback onImportNetworkWallet;
  final WalletHomeDesktopConfig desktop;

  const WalletHomeScreen({
    super.key,
    required this.createSetupCubit,
    required this.onEmptyMainnet,
    required this.onImportNetworkWallet,
    this.desktop = const WalletHomeDesktopConfig(),
  });

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  GoRouter? _router;
  bool _homeVisible = false;

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
    final visible = location == WalletRoute.walletHome.path;
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
    context.read<WalletBloc>().add(const RefreshSpWallet());
    context.read<WalletBloc>().add(const WalletRefreshed());
    // Only a price that never loaded (e.g. an offline start) is retried here:
    // re-fetching a working one would hit the price API on every navigation.
    final priceBloc = context.read<BitcoinPriceBloc>();
    if (!priceBloc.state.hasValidFiatRate && !priceBloc.state.loadingPrice) {
      priceBloc.add(const BitcoinPriceFetched());
    }
  }

  @override
  Widget build(BuildContext context) {
    final noWallets = context.select(
      (WalletBloc bloc) => bloc.state.noWalletsFound,
    );
    if (noWallets) {
      return EmptyNetworkWallets(
        createSetupCubit: widget.createSetupCubit,
        onMainnet: widget.onEmptyMainnet,
        onImport: widget.onImportNetworkWallet,
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {},
      child: context.isDesktopLayout
          ? WalletHomeDesktopBody(config: widget.desktop)
          : const WalletHomeMobileBody(),
    );
  }
}
