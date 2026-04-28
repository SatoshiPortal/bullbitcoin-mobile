import 'package:bb_mobile/core/mempool/domain/services/mempool_url_builder.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/dialog/blurred_dialog.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:satoshifier/satoshifier.dart';
import 'package:url_launcher/url_launcher.dart';

/// Displays a blockchain address truncated to fit the available width.
///
/// - **Tap** opens a dialog showing the full address in 4-char groups
///   with copy/explore actions.
/// - **Long press** copies the address to the clipboard.
///
/// The network (bitcoin/liquid, mainnet/testnet) is detected automatically
/// via [Satoshifier].
class AddressViewer extends StatelessWidget {
  const AddressViewer(
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
      onTap: () => _showDetailDialog(context),
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

  Future<String?> _getExplorerUrl() async {
    final builder = locator<MempoolUrlBuilder>();
    final parsed = await Satoshifier.tryParse(data);
    if (parsed is BitcoinAddress) {
      return builder.bitcoinAddress(data, isTestnet: parsed.network.isTestnet);
    } else if (parsed is LiquidAddress) {
      return builder.liquidAddress(data, isTestnet: parsed.network.isTestnet);
    }
    return null;
  }

  void _showDetailDialog(BuildContext context) {
    BlurredDialog.show(
      context: context,
      builder: (dialogContext) => _AddressDetailSheet(
        data: data,
        clipboardText: clipboardText ?? data,
        dialogContext: dialogContext,
        getExplorerUrl: _getExplorerUrl,
      ),
    );
  }
}

class _AddressDetailSheet extends StatelessWidget {
  const _AddressDetailSheet({
    required this.data,
    required this.clipboardText,
    required this.dialogContext,
    required this.getExplorerUrl,
  });

  final String data;
  final String clipboardText;
  final BuildContext dialogContext;
  final Future<String?> Function() getExplorerUrl;

  static const int _groupSize = 4;

  List<String> get _groups {
    final groups = <String>[];
    for (int i = 0; i < data.length; i += _groupSize) {
      final end = i + _groupSize > data.length ? data.length : i + _groupSize;
      groups.add(data.substring(i, end));
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
            context.loc.addressViewerTitle,
            style: context.font.titleSmall,
            color: context.appColors.onSurface,
          ),
          const Gap(16),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (int i = 0; i < _groups.length; i++)
                Text(
                  _groups[i],
                  style: context.font.bodyLarge?.copyWith(
                    color: i.isOdd
                        ? context.appColors.textMuted
                        : context.appColors.secondary,
                    fontWeight: i.isOdd ? FontWeight.w700 : null,
                    fontFeatures: [const FontFeature.tabularFigures()],
                    letterSpacing: 1.2,
                  ),
                ),
            ],
          ),
          const Gap(24),
          _buildCopyAction(context),
          const Gap(16),
          _buildCopyLinkAction(context),
          const Gap(16),
          _buildOpenLinkAction(context),
        ],
      ),
    );
  }

  Widget _buildCopyAction(BuildContext context) {
    return GestureDetector(
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
    );
  }

  Widget _buildCopyLinkAction(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final url = await getExplorerUrl();
        if (url == null) return;
        Clipboard.setData(ClipboardData(text: url));
        if (dialogContext.mounted) {
          Navigator.of(dialogContext).pop();
          SnackBarUtils.showCopiedSnackBar(dialogContext);
        }
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.link, size: 14, color: context.appColors.primary),
          const Gap(4),
          BBText(
            context.loc.viewerCopyLink,
            style: context.font.bodySmall,
            color: context.appColors.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildOpenLinkAction(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final url = await getExplorerUrl();
        if (url == null) return;
        if (dialogContext.mounted) {
          Navigator.of(dialogContext).pop();
        }
        await launchUrl(Uri.parse(url));
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.open_in_new, size: 14, color: context.appColors.primary),
          const Gap(4),
          BBText(
            context.loc.viewerViewInExplorer,
            style: context.font.bodySmall,
            color: context.appColors.secondary,
          ),
        ],
      ),
    );
  }
}
