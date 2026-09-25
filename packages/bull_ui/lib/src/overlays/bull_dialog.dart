import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/material.dart';

/// Centered modal dialog — duplicated from
/// `core/widgets/dialog/blurred_dialog.dart`.
///
/// When [child] is an [AlertDialog] or [SimpleDialog] it is rendered directly,
/// since those already provide their own chrome. Otherwise it is wrapped in a
/// themed [Dialog] shell.
class BullDialog extends StatelessWidget {
  const BullDialog({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(BullSpacing.lg),
  });

  /// The dialog content.
  final Widget child;

  /// Inset around [child]. Defaults to `BullSpacing.lg` so content never sits
  /// flush against the dialog border; pass `EdgeInsets.zero` to opt out.
  final EdgeInsetsGeometry padding;

  /// Present [builder]'s widget as a centered, themed dialog. The builder
  /// receives the dialog's own [BuildContext] (use it for `Navigator.of`).
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isDismissible = true,
  }) {
    final colors = context.bull;
    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      barrierColor: colors.surface.withAlpha(100),
      builder: (dialogContext) => BullDialog(child: builder(dialogContext)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    if (child is AlertDialog || child is SimpleDialog) {
      return child;
    }
    return Dialog(
      backgroundColor: colors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.secondaryFixedDim),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
