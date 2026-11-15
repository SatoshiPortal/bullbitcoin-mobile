import 'package:bull_ui/src/layout/bull_breakpoints.dart';
import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Presents a pushed page as a centred column on a desktop window, instead of
/// stretching a phone layout over the full width.
///
/// Below [BullBreakpoints.desktop] it behaves like the standard Material
/// transition, so a narrow desktop window keeps the phone presentation.
class BullDesktopPageTransitionsBuilder extends PageTransitionsBuilder {
  const BullDesktopPageTransitionsBuilder();

  static const _narrow = ZoomPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (!context.isDesktopLayout) {
      return _narrow.buildTransitions(
        route,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: _CentredPage(child: child),
    );
  }
}

class _CentredPage extends StatelessWidget {
  const _CentredPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final radius = BorderRadius.circular(context.bullShapes.sheet);
    return ColoredBox(
      color: colors.surfaceContainer,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: BullSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: BullBreakpoints.pageMaxWidth,
            ),
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: colors.outlineVariant),
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: LayoutBuilder(
                  builder: (context, constraints) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      size: constraints.biggest,
                      padding: EdgeInsets.zero,
                      viewPadding: EdgeInsets.zero,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
