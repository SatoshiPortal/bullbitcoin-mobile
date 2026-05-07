import 'package:bb_mobile/core/widgets/bb_refresh_indicator.dart';
import 'package:flutter/material.dart';

/// Standard pull-to-refresh body. Use this for any screen that supports
/// pull-to-refresh — it enforces the three invariants that make the gesture
/// reliable across the whole screen:
///
/// 1. Single scrollable (CustomScrollView) so notifications never fight with
///    nested ListView/SingleChildScrollView.
/// 2. `AlwaysScrollableScrollPhysics` so short content can still overscroll
///    and trigger refresh.
/// 3. `SliverFillRemaining(hasScrollBody: false)` appended so the scrollable
///    fills the viewport — the pull gesture works from anywhere on screen,
///    including any [bottomChild] that gets pinned to the bottom.
///
/// Pass screen content as [slivers]. If the screen has a footer (action
/// buttons, etc.) supply it as [bottomChild]; it will be pushed to the
/// bottom of the viewport when content is short, and follow the content
/// when it overflows.
class BBPullableBody extends StatelessWidget {
  const BBPullableBody({
    super.key,
    this.indicatorKey,
    required this.onRefresh,
    required this.slivers,
    this.bottomChild,
  });

  /// Forwarded to the inner [BBRefreshIndicator]. Use a
  /// `GlobalKey<RefreshIndicatorState>` to call `.show()` programmatically.
  final Key? indicatorKey;
  final RefreshCallback onRefresh;
  final List<Widget> slivers;
  final Widget? bottomChild;

  @override
  Widget build(BuildContext context) {
    return BBRefreshIndicator(
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
