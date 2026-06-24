import 'package:bull_ui/src/feedback/bull_refresh_indicator.dart';
import 'package:flutter/material.dart';

/// Standard pull-to-refresh body — duplicated from
/// `core/widgets/bb_pullable_body.dart` (`BBPullableBody`).
///
/// Wraps [slivers] in a single [CustomScrollView] with always-scrollable
/// physics and a trailing `SliverFillRemaining` so the gesture is accepted
/// anywhere on screen, even over a bottom-pinned [bottomChild].
class BullPullableBody extends StatelessWidget {
  const BullPullableBody({
    super.key,
    this.indicatorKey,
    required this.onRefresh,
    required this.slivers,
    this.bottomChild,
  });

  /// Forwarded to the inner [BullRefreshIndicator]; use a
  /// `GlobalKey<RefreshIndicatorState>` to call `.show()` programmatically.
  final Key? indicatorKey;

  /// Invoked on pull-to-refresh.
  final RefreshCallback onRefresh;

  /// The screen content slivers.
  final List<Widget> slivers;

  /// Optional footer pinned to the bottom of the viewport.
  final Widget? bottomChild;

  @override
  Widget build(BuildContext context) {
    return BullRefreshIndicator(
      indicatorKey: indicatorKey,
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          ...slivers,
          SliverFillRemaining(
            hasScrollBody: false,
            child: bottomChild == null
                ? const SizedBox.shrink()
                : Column(children: [const Spacer(), bottomChild!]),
          ),
        ],
      ),
    );
  }
}
