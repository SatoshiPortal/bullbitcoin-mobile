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
            final truncated = fitToWidth(
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

  /// Fits [data] on one line inside [maxWidth], keeping both ends visible.
  ///
  /// [measure] exists so tests can count the layout passes instead of timing
  /// them; production always measures with the real text style.
  @visibleForTesting
  static String fitToWidth(
    String data,
    TextStyle style,
    double maxWidth, {
    double Function(String text, TextStyle style)? measure,
  }) {
    final widthOf = measure ?? _measure;
    if (data.isEmpty) return data;
    if (widthOf(data, style) <= maxWidth) return data;

    const separator = '…';
    const minChars = 5;

    if (data.length <= minChars * 2) return data;

    final maxSide = (data.length - 1) ~/ 2;
    String truncatedAt(int keep) =>
        '${data.substring(0, keep)}$separator'
        '${data.substring(data.length - keep)}';

    if (!_isAsciiIdentifier(data)) {
      // A combining mark or a joined grapheme cluster can make a wider
      // truncation narrower, so anything but an ASCII identifier keeps the
      // original one-character-at-a-time scan.
      for (var keep = maxSide; keep >= minChars; keep--) {
        if (widthOf(truncatedAt(keep), style) <= maxWidth) {
          return truncatedAt(keep);
        }
      }
      return truncatedAt(minChars);
    }

    // For an ASCII identifier a wider truncation is never narrower, so the
    // number of characters kept can be searched instead of shrunk one at a
    // time: ~8 layouts instead of ~170 for a 383-character invoice. The
    // property is checked against the shipped theme font in
    // `bull_value_viewer_fit_test.dart`, which also compares this search with
    // the scan above.
    var low = minChars;
    var high = maxSide;
    var widest = 0;
    while (low <= high) {
      final keep = low + (high - low) ~/ 2;
      if (widthOf(truncatedAt(keep), style) <= maxWidth) {
        widest = keep;
        low = keep + 1;
      } else {
        high = keep - 1;
      }
    }

    return truncatedAt(widest == 0 ? minChars : widest);
  }

  /// Whether every code unit of [data] is a printable ASCII character other
  /// than a space.
  ///
  /// The bounded search above assumes that width never falls while the kept
  /// character count grows. That holds for the single-token identifiers this
  /// viewer renders (invoice, address, public key, txid) and is verified for
  /// the shipped font, but a text whose graphemes span several code units does
  /// not have it: appending a zero-width joiner or a combining mark can shrink
  /// the laid-out line.
  static bool _isAsciiIdentifier(String data) {
    for (var i = 0; i < data.length; i++) {
      final unit = data.codeUnitAt(i);
      if (unit < 0x21 || unit > 0x7E) return false;
    }
    return true;
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
    return Padding(
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
