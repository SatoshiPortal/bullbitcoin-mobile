import 'package:bb_mobile/core/mempool/domain/services/mempool_url_builder.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/dialog/blurred_dialog.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/viewer_action_button.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:url_launcher/url_launcher.dart';

enum _TransactionNetwork { bitcoin, liquid }

/// Displays a transaction ID truncated to fit the available width.
///
/// - **Tap** opens a dialog showing the full txid with copy/explore actions.
/// - **Long press** copies the txid to the clipboard.
///
/// Use the named constructors to specify the network:
/// - [TransactionViewer.bitcoin] for on-chain Bitcoin transactions.
/// - [TransactionViewer.liquid] for Liquid transactions.
class TransactionViewer extends StatelessWidget {
  const TransactionViewer.bitcoin(
    this.data, {
    super.key,
    this.style,
    this.color,
    this.clipboardText,
    required this._isTestnet,
  }) : _network = _TransactionNetwork.bitcoin,
       _unblindedUrl = null;

  const TransactionViewer.liquid(
    this.data, {
    super.key,
    this.style,
    this.color,
    this.clipboardText,
    required this._isTestnet,
    this._unblindedUrl,
  }) : _network = _TransactionNetwork.liquid;

  final String data;
  final TextStyle? style;
  final Color? color;

  /// Text copied to clipboard on long press. Defaults to [data].
  final String? clipboardText;

  final _TransactionNetwork _network;
  final bool _isTestnet;
  final String? _unblindedUrl;

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

  Future<String> _getExplorerUrl() async {
    switch (_network) {
      case _TransactionNetwork.bitcoin:
        final builder = locator<MempoolUrlBuilder>();
        return builder.bitcoinTxid(data, isTestnet: _isTestnet);
      case _TransactionNetwork.liquid:
        final builder = locator<MempoolUrlBuilder>();
        return builder.liquidTxid(
          data,
          isTestnet: _isTestnet,
          unblindedUrl: _unblindedUrl,
        );
    }
  }

  void _showDetailDialog(BuildContext context) {
    BlurredDialog.show(
      context: context,
      builder: (dialogContext) => _TransactionDetailSheet(
        data: data,
        clipboardText: clipboardText ?? data,
        dialogContext: dialogContext,
        getExplorerUrl: _getExplorerUrl,
      ),
    );
  }
}

class _TransactionDetailSheet extends StatelessWidget {
  const _TransactionDetailSheet({
    required this.data,
    required this.clipboardText,
    required this.dialogContext,
    required this.getExplorerUrl,
  });

  final String data;
  final String clipboardText;
  final BuildContext dialogContext;
  final Future<String> Function() getExplorerUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BBText(
            context.loc.transactionViewerTitle,
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
    return ViewerActionButton(
      icon: Icons.copy,
      label: context.loc.viewerTapToCopy,
      onTap: () {
        Clipboard.setData(ClipboardData(text: clipboardText));
        Navigator.of(dialogContext).pop();
        SnackBarUtils.showCopiedSnackBar(dialogContext);
      },
    );
  }

  Widget _buildCopyLinkAction(BuildContext context) {
    return ViewerActionButton(
      icon: Icons.link,
      label: context.loc.viewerCopyLink,
      onTap: () async {
        final url = await getExplorerUrl();
        Clipboard.setData(ClipboardData(text: url));
        if (dialogContext.mounted) {
          Navigator.of(dialogContext).pop();
          SnackBarUtils.showCopiedSnackBar(dialogContext);
        }
      },
    );
  }

  Widget _buildOpenLinkAction(BuildContext context) {
    return ViewerActionButton(
      icon: Icons.open_in_new,
      label: context.loc.viewerViewInExplorer,
      onTap: () async {
        final url = await getExplorerUrl();
        if (dialogContext.mounted) {
          Navigator.of(dialogContext).pop();
        }
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      },
    );
  }
}
