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

/// Pull-to-refresh wrapper — duplicated from `core/widgets/bb_refresh_indicator.dart`.
///
/// Centers the spinner vertically so it never overlaps the top bar. The [child]
/// must be a single scrollable that fills the viewport so the gesture is
/// accepted from anywhere on the screen.
class BullRefreshIndicator extends StatelessWidget {
  const BullRefreshIndicator({
    super.key,
    this.indicatorKey,
    required this.onRefresh,
    required this.child,
  });

  /// Forwarded to the inner [RefreshIndicator]; use a
  /// `GlobalKey<RefreshIndicatorState>` to call `.show()` programmatically.
  final Key? indicatorKey;

  /// Invoked when the user pulls to refresh.
  final RefreshCallback onRefresh;

  /// The scrollable content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final offset = (screenHeight * 0.40 - 60).clamp(0.0, screenHeight);
    return ScrollConfiguration(
      behavior: const _PullToRefreshScrollBehavior(),
      child: RefreshIndicator(
        key: indicatorKey,
        edgeOffset: offset,
        onRefresh: onRefresh,
        child: child,
      ),
    );
  }
}
