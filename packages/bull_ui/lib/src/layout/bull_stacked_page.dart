import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/widgets.dart';

/// A full-bleed page with a gradient-faded footer pinned to the bottom —
/// duplicated from `core/widgets/template/screen_template.dart` (`StackedPage`).
///
/// [child] fills the screen; [bottomChild] (typically action buttons) floats
/// over it behind a bottom-up gradient that fades into the surface colour.
class BullStackedPage extends StatelessWidget {
  const BullStackedPage({
    super.key,
    required this.child,
    required this.bottomChild,
  });

  /// The main page content (fills the available space).
  final Widget child;

  /// The footer pinned to the bottom over a fading gradient.
  final Widget bottomChild;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.only(
              bottom: 32,
              top: 8,
              left: 16,
              right: 16,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.onSecondary.withValues(alpha: 0.0),
                  colors.onSecondary,
                ],
                stops: const [0.0, 0.3],
              ),
            ),
            child: bottomChild,
          ),
        ),
      ],
    );
  }
}
