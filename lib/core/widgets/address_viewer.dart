import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/dialog/blurred_dialog.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

/// Displays an address that adapts to the available width.
///
/// Shows as many characters as fit on a single line (minimum 5 head + 5 tail
/// with "…" in the middle). If the full address fits, no truncation is applied.
///
/// - **Tap** opens a bottom sheet showing the full address split into
///   groups of 4 for easy visual verification.
/// - **Long press** copies the full address to the clipboard.
class AddressViewer extends StatelessWidget {
  const AddressViewer(this.address, {super.key, this.style, this.color});

  final String address;
  final TextStyle? style;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? context.appColors.secondary;
    final textStyle = style ?? context.font.bodyLarge;

    return GestureDetector(
      onTap: () => _showAddressSheet(context),
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: address));
        SnackBarUtils.showCopiedSnackBar(context);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final truncated = _fitToWidth(
            address,
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

  /// Returns the address truncated to fit [maxWidth], or the full address
  /// if it fits. Minimum truncation keeps 5 chars on each side.
  static String _fitToWidth(String address, TextStyle style, double maxWidth) {
    if (_measure(address, style) <= maxWidth) return address;

    const separator = '…';
    const minChars = 5;

    // Start from the maximum possible and shrink until it fits
    final maxSide = (address.length - 1) ~/ 2;
    for (int n = maxSide; n >= minChars; n--) {
      final truncated =
          '${address.substring(0, n)}$separator${address.substring(address.length - n)}';
      if (_measure(truncated, style) <= maxWidth) return truncated;
    }

    // Absolute fallback
    return '${address.substring(0, minChars)}$separator${address.substring(address.length - minChars)}';
  }

  static double _measure(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  void _showAddressSheet(BuildContext context) {
    BlurredDialog.show(
      context: context,
      builder: (dialogContext) =>
          _AddressDetailSheet(address: address, dialogContext: dialogContext),
    );
  }
}

class _AddressDetailSheet extends StatelessWidget {
  const _AddressDetailSheet({
    required this.address,
    required this.dialogContext,
  });

  final String address;
  final BuildContext dialogContext;

  static const int _groupSize = 4;

  List<String> get _groups {
    final groups = <String>[];
    for (int i = 0; i < address.length; i += _groupSize) {
      final end = i + _groupSize > address.length
          ? address.length
          : i + _groupSize;
      groups.add(address.substring(i, end));
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BBText(
            'Address',
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
              Clipboard.setData(ClipboardData(text: address));
              Navigator.of(dialogContext).pop();
              SnackBarUtils.showCopiedSnackBar(dialogContext);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.copy, size: 14, color: context.appColors.primary),
                const Gap(4),
                BBText(
                  'Tap to copy',
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
