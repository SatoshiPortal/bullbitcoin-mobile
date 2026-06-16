import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/material.dart';

/// Centered modal dialog — duplicated from
/// `core/widgets/dialog/blurred_dialog.dart`. Used for the freeze confirm modal.
class BullDialog extends StatelessWidget {
  const BullDialog({super.key, required this.child});

  /// The dialog content.
  final Widget child;

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
      barrierColor: colors.text.withValues(alpha: 0.5),
      builder: (dialogContext) => BullDialog(child: builder(dialogContext)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Dialog(
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: child,
    );
  }
}
