import 'package:flutter/material.dart';

/// Pull-to-refresh wrapper that centers the spinner on the screen so it
/// never overlaps the AppBar. Behavior parity is the goal — every screen
/// using this widget gets the same gesture feel and indicator placement.
///
/// To make the gesture work across the full screen (including footer
/// buttons), the [child] must be a single scrollable that fills the
/// viewport. Two patterns are supported per screen layout:
///
/// 1. Sliver layouts: `CustomScrollView` with a
///    `SliverFillRemaining(hasScrollBody: false)` hosting the bottom
///    widgets.
/// 2. Box layouts: `LayoutBuilder` + `SingleChildScrollView` +
///    `ConstrainedBox(minHeight)` + `IntrinsicHeight` + `Spacer` to push
///    the bottom widgets down inside the scroll view.
///
/// Either way, the pull gesture is accepted from anywhere on the screen
/// because the entire viewport belongs to the scroll view.
class BBRefreshIndicator extends StatelessWidget {
  const BBRefreshIndicator({
    super.key,
    this.indicatorKey,
    required this.onRefresh,
    required this.child,
  });

  /// Forwarded to the inner [RefreshIndicator]. Use a
  /// `GlobalKey<RefreshIndicatorState>` to call `.show()` programmatically.
  final Key? indicatorKey;
  final RefreshCallback onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Position the spinner around the upper third of the actual scroll
    // area (not the full screen — MediaQuery would include the bottom
    // nav and bias the indicator toward the bottom of the body).
    // 60 = default RefreshIndicator displacement (40) + half indicator
    // height (~20). The displacement is left at its native value to
    // preserve drag feel.
    return LayoutBuilder(
      builder: (context, constraints) => RefreshIndicator(
        key: indicatorKey,
        edgeOffset: constraints.maxHeight * 0.4 - 60,
        onRefresh: onRefresh,
        child: child,
      ),
    );
  }
}
