import 'package:bull_ui/src/feedback/bull_fading_linear_progress.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

class _PullToRefreshScrollBehavior extends MaterialScrollBehavior {
  const _PullToRefreshScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.unknown,
  };
}

/// Pull-to-refresh wrapper.
///
/// No spinner: while the refresh runs, a thin line runs along the top edge of
/// the body, just under the top bar, or under the status bar when the body
/// reaches behind it. The [child] must be a single scrollable
/// that fills the viewport so the gesture is accepted from anywhere on the
/// screen.
class BullRefreshIndicator extends StatefulWidget {
  const BullRefreshIndicator({
    super.key,
    this.indicatorKey,
    required this.onRefresh,
    this.showProgress = true,
    required this.child,
  });

  /// Forwarded to the inner [RefreshIndicator]; use a
  /// `GlobalKey<RefreshIndicatorState>` to call `.show()` programmatically.
  final Key? indicatorKey;

  /// Invoked when the user pulls to refresh.
  final RefreshCallback onRefresh;

  /// Whether the line is drawn. Off when the screen already shows its own
  /// progress, as the wallet cards do on home.
  final bool showProgress;

  /// The scrollable content.
  final Widget child;

  @override
  State<BullRefreshIndicator> createState() => _BullRefreshIndicatorState();
}

class _BullRefreshIndicatorState extends State<BullRefreshIndicator> {
  bool _refreshing = false;

  void _onStatusChange(RefreshIndicatorStatus? status) {
    final refreshing = status == RefreshIndicatorStatus.refresh;
    if (refreshing != _refreshing && mounted) {
      setState(() => _refreshing = refreshing);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const _PullToRefreshScrollBehavior(),
      child: Stack(
        children: [
          RefreshIndicator.noSpinner(
            key: widget.indicatorKey,
            onRefresh: widget.onRefresh,
            onStatusChange: _onStatusChange,
            child: widget.child,
          ),
          if (widget.showProgress)
            Positioned(
              top: MediaQuery.paddingOf(context).top,
              left: 0,
              right: 0,
              child: BullFadingLinearProgress(trigger: _refreshing),
            ),
        ],
      ),
    );
  }
}
