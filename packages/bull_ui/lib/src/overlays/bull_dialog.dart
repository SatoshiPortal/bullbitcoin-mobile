import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_shapes.dart';
import 'package:material_ui/material_ui.dart';

/// Centered modal dialog.
///
/// When [child] is an [AlertDialog] or [SimpleDialog] it is rendered directly,
/// since those already provide their own chrome. Otherwise it is wrapped in a
/// themed [Dialog] shell and scrolls vertically when it exceeds the available
/// height.
class BullDialog extends StatelessWidget {
  const BullDialog({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(BullSpacing.lg),
    this.fullscreen = false,
  });

  /// Custom centered content lays out at its natural height inside the scroll
  /// view. Give children that need a bounded height their own constraints.
  final Widget child;

  /// Full-screen transparent chrome for a caller-owned overlay.
  /// The panel must claim taps within its bounds; unclaimed taps reach the
  /// native route barrier. The caller owns safe-area and content padding.
  final bool fullscreen;

  /// Inset around [child]. Defaults to `BullSpacing.lg` so content never sits
  /// flush against the dialog border; pass `EdgeInsets.zero` to opt out.
  /// Fullscreen content owns its padding instead.
  final EdgeInsetsGeometry padding;

  /// Present [builder]'s widget as a centered, themed dialog. The builder
  /// receives the dialog's own [BuildContext] (use it for `Navigator.of`).
  ///
  /// Pass [padding] as `EdgeInsets.zero` when the child already insets itself,
  /// otherwise the two stack.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isDismissible = true,
    bool fullscreen = false,
    Color? barrierColor,
    EdgeInsetsGeometry padding = const EdgeInsets.all(BullSpacing.lg),
  }) {
    final colors = context.bull;
    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      useSafeArea: !fullscreen,
      barrierColor:
          barrierColor ??
          colors.scrim.withValues(
            alpha: Theme.of(context).brightness == Brightness.light
                ? 0.45
                : 0.60,
          ),
      builder: (dialogContext) => BullDialog(
        padding: padding,
        fullscreen: fullscreen,
        child: builder(dialogContext),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    if (fullscreen) {
      return Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        child: SizedBox.expand(
          child: Material(type: MaterialType.transparency, child: child),
        ),
      );
    }
    if (child is AlertDialog || child is SimpleDialog) {
      return child;
    }
    return Dialog(
      backgroundColor: colors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.bullShapes.sheet),
        side: BorderSide(color: colors.border),
      ),
      child: SingleChildScrollView(
        primary: false,
        padding: padding,
        child: child,
      ),
    );
  }
}
