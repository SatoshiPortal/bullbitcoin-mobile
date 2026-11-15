import 'dart:async';

import 'package:bb_mobile/features/receive/domain/usecases/poll_receive_wallet_usecase.dart';
import 'package:bb_mobile/features/receive/ui/receive_router.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Screen-local scheduling; revisions still drive the existing address watcher.
class ReceivePolling extends StatefulWidget {
  final String? walletId;
  final bool isLiquid;
  final int? revealGeneration;
  final PollReceiveWalletUsecase poll;
  final Widget child;

  const ReceivePolling({
    super.key,
    required this.walletId,
    required this.isLiquid,
    this.revealGeneration,
    required this.poll,
    required this.child,
  });

  // Leave both native engines idle for 20 seconds after each completed pass.
  static const receiveResyncDelay = Duration(seconds: 20);

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
        if (!_resumed) {
          _restart();
          return;
        }
        // Background frames may be suspended; first consume current bloc state.
        final generation = _generation;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _resumed && _generation == generation) _restart();
        });
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
        oldWidget.isLiquid != widget.isLiquid ||
        oldWidget.revealGeneration != widget.revealGeneration) {
      _restart();
    }
  }

  void _restart() {
    _timer?.cancel();
    final generation = ++_generation;
    final walletId = widget.walletId;
    if (!_resumed ||
        !_visible ||
        walletId == null ||
        widget.revealGeneration == null) {
      return;
    }
    _sync(walletId, generation).ignore();
  }

  Future<void> _sync(String walletId, int generation) async {
    bool isActive() => mounted && _generation == generation;
    try {
      // The facade future settles at the requested or already covering pass end.
      await widget.poll.execute(walletId, isActive: isActive);
    } finally {
      if (isActive()) {
        _timer = Timer(
          ReceivePolling.receiveResyncDelay,
          () => _sync(walletId, generation).ignore(),
        );
      }
    }
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
