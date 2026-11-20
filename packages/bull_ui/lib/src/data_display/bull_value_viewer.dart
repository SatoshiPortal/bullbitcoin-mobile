import 'package:bull_ui/src/buttons/bull_viewer_action_button.dart';
import 'package:bull_ui/src/data_display/bull_text.dart';
import 'package:bull_ui/src/feedback/bull_snack_bar.dart';
import 'package:bull_ui/src/layout/gap.dart';
import 'package:bull_ui/src/overlays/bull_dialog.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_typography.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Package-internal rendering for view-and-copy value components.
class BullValueViewer extends StatelessWidget {
  const BullValueViewer(
    this.data, {
    super.key,
    required this.title,
    required this.copyLabel,
    required this.copiedMessage,
    this.additionalActions,
    this.style,
    this.color,
    this.clipboardText,
  });

  final String data;
  final String title;
  final String copyLabel;
  final String copiedMessage;
  final TextStyle? style;
  final Color? color;

  /// Text copied in place of the displayed value.
  final String? clipboardText;

  final List<Widget> Function(BuildContext)? additionalActions;

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? context.bull.secondary;
    final textStyle =
        style ?? context.bullType.body.copyWith(fontWeight: FontWeight.w500);
    final effectiveStyle = textStyle.copyWith(
      color: textColor,
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.dotted,
      decorationColor: textColor.withAlpha(120),
    );

    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showDetailDialog(context),
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: clipboardText ?? data));
          BullSnackBar.show(context, message: copiedMessage);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final truncated = _fitToWidth(
              data,
              effectiveStyle,
              constraints.maxWidth,
            );
            return ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1,
                child: BullText(
                  truncated,
                  style: effectiveStyle,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static String _fitToWidth(String data, TextStyle style, double maxWidth) {
    if (data.isEmpty) return data;
    if (_measure(data, style) <= maxWidth) return data;

    const separator = '…';
    const minChars = 5;

    if (data.length <= minChars * 2) return data;

    final maxSide = (data.length - 1) ~/ 2;
    for (int n = maxSide; n >= minChars; n--) {
      final truncated =
          '${data.substring(0, n)}$separator${data.substring(data.length - n)}';
      if (_measure(truncated, style) <= maxWidth) return truncated;
    }

    return '${data.substring(0, minChars)}$separator${data.substring(data.length - minChars)}';
  }

  static double _measure(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  void _showDetailDialog(BuildContext context) {
    showDetail(
      context,
      data: data,
      clipboardText: clipboardText,
      title: title,
      copyLabel: copyLabel,
      copiedMessage: copiedMessage,
      additionalActions: additionalActions,
    );
  }

  static Future<void> showDetail(
    BuildContext context, {
    required String data,
    required String title,
    required String copyLabel,
    required String copiedMessage,
    String? clipboardText,
    List<Widget> Function(BuildContext)? additionalActions,
  }) {
    return BullDialog.show<void>(
      context: context,
      padding: EdgeInsets.zero,
      builder: (context) => _buildDialog(
        context,
        data: data,
        title: title,
        copyLabel: copyLabel,
        clipboardText: clipboardText ?? data,
        copiedMessage: copiedMessage,
        additionalActions: additionalActions,
      ),
    );
  }

  static Widget _buildDialog(
    BuildContext context, {
    required String data,
    required String title,
    required String copyLabel,
    required String clipboardText,
    required String copiedMessage,
    required List<Widget> Function(BuildContext)? additionalActions,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: BullText(
              title,
              style: context.bullType.label,
              color: context.bull.onSurface,
            ),
          ),
          const Gap(16),
          SelectableText(
            data,
            style: context.bullType.body
                .copyWith(fontWeight: FontWeight.w500)
                .copyWith(
                  color: context.bull.secondary,
                  fontFeatures: [const FontFeature.tabularFigures()],
                  letterSpacing: 1.2,
                ),
            textAlign: TextAlign.center,
          ),
          const Gap(24),
          actionButton(
            icon: Icons.copy,
            label: copyLabel,
            onTap: () => copyFromDialog(context, clipboardText, copiedMessage),
          ),
          ...?additionalActions?.call(context),
        ],
      ),
    );
  }

  static Widget actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    child: BullViewerActionButton(icon: icon, label: label, onTap: onTap),
  );

  static void copyFromDialog(
    BuildContext context,
    String value,
    String copiedMessage,
  ) {
    Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      Navigator.of(context).pop();
      BullSnackBar.show(context, message: copiedMessage);
    }
  }
}
