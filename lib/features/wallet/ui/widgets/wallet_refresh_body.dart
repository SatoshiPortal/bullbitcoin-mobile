import 'package:bull_ui/bull_ui.dart';

/// Shows foreground work without turning an automatic refresh into a pull.
class WalletRefreshBody extends StatefulWidget {
  final bool isRefreshing;
  final Future<void> Function() waitForRefresh;
  final Future<void> Function() onRefresh;
  final List<Widget> slivers;
  final double bottomInset;

  const WalletRefreshBody({
    super.key,
    required this.isRefreshing,
    required this.waitForRefresh,
    required this.onRefresh,
    required this.slivers,
    this.bottomInset = 0,
  });

  @override
  State<WalletRefreshBody> createState() => _WalletRefreshBodyState();
}

class _WalletRefreshBodyState extends State<WalletRefreshBody> {
  final _indicatorKey = GlobalKey<RefreshIndicatorState>();
  bool _showingExistingRefresh = false;

  @override
  void initState() {
    super.initState();
    _showRefresh();
  }

  @override
  void didUpdateWidget(WalletRefreshBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isRefreshing && widget.isRefreshing) _showRefresh();
  }

  void _showRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !widget.isRefreshing || _showingExistingRefresh) return;
      final indicator = _indicatorKey.currentState;
      if (indicator == null) return;
      // show() invokes onRefresh after its entrance animation. Keep this flag
      // until the entire indicator cycle ends, including that delayed callback.
      _showingExistingRefresh = true;
      try {
        await indicator.show();
      } finally {
        _showingExistingRefresh = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) => BullPullableBody(
    indicatorKey: _indicatorKey,
    onRefresh: () =>
        _showingExistingRefresh ? widget.waitForRefresh() : widget.onRefresh(),
    bottomInset: widget.bottomInset,
    slivers: widget.slivers,
  );
}
