import 'dart:async';

import 'package:flutter/widgets.dart';

/// Refreshes one wallet; the future settles when the covering pass ends.
typedef SettlementPoll = Future<void> Function(
  String walletId, {
  required bool Function() isActive,
});

/// Screen-scoped polling of the wallet that holds a settlement transaction.
///
/// Runs only while [active], the app is resumed and the enclosing route is the
/// current one. Each pass is awaited, then the widget waits 60 seconds for
/// Bitcoin or 20 seconds for Liquid before the next pass, so passes never
/// overlap. Scheduling stays in widget state; [poll] owns admission and logging.
class SettlementSyncPoller extends StatefulWidget {
  final String? walletId;
  final bool active;
  final bool isLiquid;
  final SettlementPoll poll;
  final Widget child;

  const SettlementSyncPoller({
    super.key,
    required this.walletId,
    required this.active,
    required this.isLiquid,
    required this.poll,
    required this.child,
  });

  static const bitcoinDelay = Duration(seconds: 60);
  static const liquidDelay = Duration(seconds: 20);

  @override
  State<SettlementSyncPoller> createState() => _SettlementSyncPollerState();
}

class _SettlementSyncPollerState extends State<SettlementSyncPoller> {
  Timer? _timer;
  late final AppLifecycleListener _lifecycle;
  bool _resumed = true;
  bool _current = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _resumed = state == null || state == AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        final resumed = state == AppLifecycleState.resumed;
        if (resumed == _resumed) return;
        _resumed = resumed;
        _restart();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    final first = _generation == 0;
    if (!first && current == _current) return;
    _current = current;
    _restart();
  }

  @override
  void didUpdateWidget(SettlementSyncPoller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.walletId != widget.walletId ||
        oldWidget.active != widget.active ||
        oldWidget.isLiquid != widget.isLiquid) {
      _restart();
    }
  }

  void _restart() {
    _timer?.cancel();
    _timer = null;
    final generation = ++_generation;
    final walletId = widget.walletId;
    if (!_resumed || !_current || !widget.active || walletId == null) return;
    _sync(walletId, generation).ignore();
  }

  Future<void> _sync(String walletId, int generation) async {
    bool isActive() => mounted && _generation == generation;
    try {
      await widget.poll(walletId, isActive: isActive);
    } on Exception {
      // A failed pass is retried after the delay; poll reports its own failures.
    }
    if (!isActive()) return;
    _timer = Timer(
      widget.isLiquid
          ? SettlementSyncPoller.liquidDelay
          : SettlementSyncPoller.bitcoinDelay,
      () => _sync(walletId, generation).ignore(),
    );
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
