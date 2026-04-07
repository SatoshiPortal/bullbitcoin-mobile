import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/dialog/blurred_dialog.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

enum _BullEyeType { address, transaction, invoice }

/// Displays a blockchain identifier (address, txid, or invoice) truncated
/// to fit the available width.
///
/// Shows as many characters as fit on a single line (minimum 5 head + 5 tail
/// with "…" in the middle). If the full text fits, no truncation is applied.
///
/// - **Tap** opens a dialog showing the full value split into groups of 4
///   for easy visual verification.
/// - **Long press** copies the value to the clipboard.
class BullEye extends StatelessWidget {
  const BullEye.address(
    this.data, {
    super.key,
    this.style,
    this.color,
    this.clipboardText,
    this.onExplore,
  }) : _type = _BullEyeType.address;

  const BullEye.transaction(
    this.data, {
    super.key,
    this.style,
    this.color,
    this.clipboardText,
    this.onExplore,
  }) : _type = _BullEyeType.transaction;

  const BullEye.invoice(
    this.data, {
    super.key,
    this.style,
    this.color,
    this.clipboardText,
    this.onExplore,
  }) : _type = _BullEyeType.invoice;

  final String data;
  final TextStyle? style;
  final Color? color;

  /// Text copied to clipboard on long press. Defaults to [data].
  /// Use this when the clipboard should contain a different value than
  /// displayed (e.g. full BIP21 URI instead of raw address).
  final String? clipboardText;

  /// Optional callback to open the value in a block explorer.
  /// When provided, the detail dialog shows a "View in explorer" button.
  final VoidCallback? onExplore;

  final _BullEyeType _type;

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? context.appColors.secondary;
    final textStyle = style ?? context.font.bodyLarge;

    return GestureDetector(
      onTap: () => _showDetailDialog(context),
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: clipboardText ?? data));
        SnackBarUtils.showCopiedSnackBar(context);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final truncated = _fitToWidth(
            data,
            textStyle?.copyWith(color: textColor) ?? const TextStyle(),
            constraints.maxWidth,
          );
          return BBText(
            truncated,
            style: textStyle,
            color: textColor,
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

  void _showDetailDialog(BuildContext context) {
    BlurredDialog.show(
      context: context,
      builder: (dialogContext) => _BullEyeDetailSheet(
        data: data,
        type: _type,
        clipboardText: clipboardText ?? data,
        dialogContext: dialogContext,
        onExplore: onExplore,
      ),
    );
  }
}

class _BullEyeDetailSheet extends StatelessWidget {
  const _BullEyeDetailSheet({
    required this.data,
    required this.type,
    required this.clipboardText,
    required this.dialogContext,
    this.onExplore,
  });

  final String data;
  final _BullEyeType type;
  final String clipboardText;
  final BuildContext dialogContext;
  final VoidCallback? onExplore;

  static const int _groupSize = 4;

  List<String> get _groups {
    final groups = <String>[];
    for (int i = 0; i < data.length; i += _groupSize) {
      final end =
          i + _groupSize > data.length ? data.length : i + _groupSize;
      groups.add(data.substring(i, end));
    }
    return groups;
  }

  String _title(BuildContext context) => switch (type) {
    _BullEyeType.address => context.loc.addressViewerTitle,
    _BullEyeType.transaction => context.loc.bullEyeTransactionTitle,
    _BullEyeType.invoice => context.loc.bullEyeInvoiceTitle,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BBText(
            _title(context),
            style: context.font.titleSmall,
            color: context.appColors.onSurface,
          ),
          const Gap(16),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final group in _groups)
                Text(
                  group,
                  style: context.font.bodyLarge?.copyWith(
                    color: context.appColors.secondary,
                    fontFeatures: [const FontFeature.tabularFigures()],
                    letterSpacing: 1.2,
                  ),
                ),
            ],
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
                  context.loc.addressViewerTapToCopy,
                  style: context.font.bodySmall,
                  color: context.appColors.secondary,
                ),
              ],
            ),
          ),
          if (onExplore != null) ...[
            const Gap(16),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(dialogContext).pop();
                onExplore!();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.open_in_new,
                    size: 14,
                    color: context.appColors.primary,
                  ),
                  const Gap(4),
                  BBText(
                    context.loc.addressViewerViewInExplorer,
                    style: context.font.bodySmall,
                    color: context.appColors.secondary,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
