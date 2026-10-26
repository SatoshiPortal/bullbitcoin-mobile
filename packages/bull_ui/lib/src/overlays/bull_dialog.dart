import 'dart:ui' show ImageFilter;
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/material.dart';

/// Centered modal dialog.
///
/// When [child] is an [AlertDialog] or [SimpleDialog] it is rendered directly,
/// since those already provide their own chrome. Otherwise it is wrapped in a
/// themed [Dialog] shell.
class BullDialog extends StatelessWidget {
  const BullDialog({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(BullSpacing.lg),
  }) : _alert = false,
       title = null,
       actions = const [];

  /// An accessible platform alert with kit-owned presentation.
  const BullDialog.alert({
    super.key,
    required this.child,
    this.title,
    this.actions = const [],
  }) : _alert = true,
       padding = EdgeInsets.zero;

  final bool _alert;
  final Widget? title;
  final List<Widget> actions;

  /// The dialog content.
  final Widget child;

  /// Inset around [child]. Defaults to `BullSpacing.lg` so content never sits
  /// flush against the dialog border; pass `EdgeInsets.zero` to opt out.
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
    EdgeInsetsGeometry padding = const EdgeInsets.all(BullSpacing.lg),
  }) {
    final colors = context.bull;
    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      barrierColor: colors.surface.withAlpha(100),
      builder: (dialogContext) =>
          BullDialog(padding: padding, child: builder(dialogContext)),
    );
  }

  /// Presents an alert variant; the builder owns localized copy and actions.
  static Future<T?> showAlert<T>({
    required BuildContext context,
    required BullDialog Function(BuildContext) builder,
    bool isDismissible = true,
    double blurSigma = 0,
    Color? barrierColor,
  }) => showDialog<T>(
    context: context,
    barrierDismissible: isDismissible,
    barrierColor: barrierColor ?? context.bull.text.withValues(alpha: .5),
    builder: (dialogContext) {
      final dialog = builder(dialogContext);
      return blurSigma == 0
          ? dialog
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: dialog,
            );
    },
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    if (_alert) {
      return AlertDialog(title: title, content: child, actions: actions);
    }
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
