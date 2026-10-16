import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

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
/// Centers the spinner vertically so it never overlaps the top bar. The [child]
/// must be a single scrollable that fills the viewport so the gesture is
/// accepted from anywhere on the screen.
class BullRefreshIndicator extends StatefulWidget {
  const BullRefreshIndicator({
    super.key,
    this.indicatorKey,
    this.isRefreshing = false,
    required this.onRefresh,
    required this.child,
  });

  /// Forwarded to the inner [RefreshIndicator]; use a
  /// `GlobalKey<RefreshIndicatorState>` to call `.show()` programmatically.
  final Key? indicatorKey;

  /// Displays external refresh activity without invoking [onRefresh].
  final bool isRefreshing;

  /// Invoked when the user pulls to refresh.
  final RefreshCallback onRefresh;

  /// The scrollable content.
  final Widget child;

  @override
  State<BullRefreshIndicator> createState() => _BullRefreshIndicatorState();
}

class _BullRefreshIndicatorState extends State<BullRefreshIndicator> {
  static const double _displacement = 40;
  bool _refreshingFromGesture = false;

  Future<void> _onRefresh() async {
    setState(() => _refreshingFromGesture = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _refreshingFromGesture = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final offset = (screenHeight * 0.40 - 60).clamp(0.0, screenHeight);
    return ScrollConfiguration(
      behavior: const _PullToRefreshScrollBehavior(),
      child: Stack(
        children: [
          RefreshIndicator(
            key: widget.indicatorKey,
            edgeOffset: offset,
            displacement: _displacement,
            onRefresh: _onRefresh,
            child: widget.child,
          ),
          if (widget.isRefreshing && !_refreshingFromGesture)
            Positioned(
              top: offset + _displacement,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: RefreshProgressIndicator(
                    semanticsLabel: MaterialLocalizations.of(
                      context,
                    ).refreshIndicatorSemanticLabel,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
