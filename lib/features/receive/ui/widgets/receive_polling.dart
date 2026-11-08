import 'dart:async';

import 'package:bb_mobile/features/receive/domain/usecases/poll_receive_wallet_usecase.dart';
import 'package:bb_mobile/features/receive/ui/receive_router.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Screen-local scheduling; revisions still drive the existing address watcher.
class ReceivePolling extends StatefulWidget {
  final String? walletId;
  final bool isLiquid;
  final PollReceiveWalletUsecase poll;
  final Widget child;

  const ReceivePolling({
    super.key,
    required this.walletId,
    required this.isLiquid,
    required this.poll,
    required this.child,
  });

  // Bitcoin revealed-script sync is cheap enough to detect a payment promptly.
  static const bitcoinInterval = Duration(seconds: 15);
  // LWK scans the full Liquid wallet, so allow twice the Bitcoin interval.
  static const liquidInterval = Duration(seconds: 30);

  @override
  State<ReceivePolling> createState() => _ReceivePollingState();
}

class _ReceivePollingState extends State<ReceivePolling> {
  Timer? _timer;
  GoRouter? _router;
  late final AppLifecycleListener _lifecycle;
  bool _resumed = false;
  bool _visible = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _resumed = state == null || state == AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _resumed = state == AppLifecycleState.resumed;
        _restart();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (!identical(router, _router)) {
      _router?.routerDelegate.removeListener(_routeChanged);
      _router = router;
      router.routerDelegate.addListener(_routeChanged);
    }
    _routeChanged();
  }

  void _routeChanged() {
    final configuration = _router?.routerDelegate.currentConfiguration;
    final top = configuration?.lastOrNull;
    // Root pushes can cover this nested shell without disposing its widgets.
    final path = top is ImperativeRouteMatch
        ? top.matches.uri.path
        : configuration?.uri.path;
    final bitcoin = ReceiveRoute.receiveBitcoin.path;
    final liquid = ReceiveRoute.receiveLiquid.path;
    final visible =
        path == bitcoin ||
        path == '$bitcoin/amount' ||
        path == liquid ||
        path == '$liquid/amount';
    if (_visible == visible) return;
    _visible = visible;
    _restart();
  }

  @override
  void didUpdateWidget(ReceivePolling oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.walletId != widget.walletId ||
        oldWidget.isLiquid != widget.isLiquid) {
      _restart();
    }
  }

  void _restart() {
    _timer?.cancel();
    final generation = ++_generation;
    final walletId = widget.walletId;
    if (!_resumed || !_visible || walletId == null) return;
    // No immediate call on entry/resume; each new visibility epoch waits fully.
    _timer = Timer.periodic(
      widget.isLiquid
          ? ReceivePolling.liquidInterval
          : ReceivePolling.bitcoinInterval,
      (_) {
        widget.poll
            .execute(
              walletId,
              isActive: () => mounted && _generation == generation,
            )
            .ignore();
      },
    );
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    _lifecycle.dispose();
    _router?.routerDelegate.removeListener(_routeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
