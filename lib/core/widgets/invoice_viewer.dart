import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/dialog/blurred_dialog.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

/// Displays a Lightning invoice truncated to fit the available width.
///
/// - **Tap** opens a dialog showing the full invoice with a copy action.
/// - **Long press** copies the invoice to the clipboard.
///
/// Unlike [AddressViewer] and [TransactionViewer], there is no explorer link.
class InvoiceViewer extends StatelessWidget {
  const InvoiceViewer(
    this.data, {
    super.key,
    this.style,
    this.color,
    this.clipboardText,
  });

  final String data;
  final TextStyle? style;
  final Color? color;

  /// Text copied to clipboard on long press. Defaults to [data].
  final String? clipboardText;

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? context.appColors.secondary;
    final textStyle = style ?? context.font.bodyLarge;
    final effectiveStyle = (textStyle ?? const TextStyle()).copyWith(
      color: textColor,
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.dotted,
      decorationColor: textColor.withAlpha(120),
    );

    return GestureDetector(
      onTap: () =>
          showDetail(context, data: data, clipboardText: clipboardText),
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: clipboardText ?? data));
        SnackBarUtils.showCopiedSnackBar(context);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final truncated = _fitToWidth(
            data,
            effectiveStyle,
            constraints.maxWidth,
          );
          return BBText(
            truncated,
            style: effectiveStyle,
            maxLines: 1,
            overflow: TextOverflow.clip,
          );
        },
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

  /// Opens the invoice detail dialog without needing a rendered
  /// [InvoiceViewer]. Use from a wrapper (e.g. a tappable tile) so the
  /// whole region around the invoice triggers the same flow.
  static Future<void> showDetail(
    BuildContext context, {
    required String data,
    String? clipboardText,
  }) {
    return BlurredDialog.show<void>(
      context: context,
      builder: (dialogContext) => _InvoiceDetailSheet(
        data: data,
        clipboardText: clipboardText ?? data,
        dialogContext: dialogContext,
      ),
    );
  }
}

class _InvoiceDetailSheet extends StatelessWidget {
  const _InvoiceDetailSheet({
    required this.data,
    required this.clipboardText,
    required this.dialogContext,
  });

  final String data;
  final String clipboardText;
  final BuildContext dialogContext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BBText(
            context.loc.invoiceViewerTitle,
            style: context.font.titleSmall,
            color: context.appColors.onSurface,
          ),
          const Gap(16),
          SelectableText(
            data,
            style: context.font.bodyLarge?.copyWith(
              color: context.appColors.secondary,
              fontFeatures: [const FontFeature.tabularFigures()],
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const Gap(24),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Clipboard.setData(ClipboardData(text: clipboardText));
              Navigator.of(dialogContext).pop();
              SnackBarUtils.showCopiedSnackBar(dialogContext);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.copy, size: 14, color: context.appColors.primary),
                const Gap(4),
                BBText(
                  context.loc.viewerTapToCopy,
                  style: context.font.bodySmall,
                  color: context.appColors.secondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
