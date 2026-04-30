import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

/// A centered dialog following the same API pattern as [BlurredBottomSheet].
///
/// When the built widget is an [AlertDialog] or [SimpleDialog], it is rendered
/// directly (they already provide their own chrome). Otherwise the widget
/// is wrapped in a themed [Dialog] shell.
class BlurredDialog extends StatelessWidget {
  const BlurredDialog({super.key, required this.child});

  final Widget child;

  /// Show a centered dialog with app-consistent styling.
  ///
  /// [builder] receives the dialog's own [BuildContext], which must be used
  /// for `Navigator.of(ctx).pop()` and `ScaffoldMessenger` lookups.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      barrierColor: context.appColors.surface.withAlpha(100),
      builder: (dialogContext) => BlurredDialog(child: builder(dialogContext)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (child is AlertDialog || child is SimpleDialog) {
      return child;
    }
    return Dialog(
      backgroundColor: context.appColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: context.appColors.secondaryFixedDim),
      ),
      child: child,
    );
  }
}
