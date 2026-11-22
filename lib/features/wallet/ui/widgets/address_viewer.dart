import 'package:primitives/primitives.dart' as primitives show Network;
import 'package:primitives/primitives.dart'
    show BitcoinNetwork, LiquidNetwork, NetworkCapabilities, NetworkCapability;
import 'package:mempool/mempool.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullDialog,
        BullSegmented,
        BullSnackBar,
        BullText,
        BullViewerActionButton,
        Gap,
        BullTypographyX;
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
    this.textAlign,
  });

  final String data;
  final TextStyle? style;
  final Color? color;

  /// Text copied to clipboard on long press. Defaults to [data].
  final String? clipboardText;

  /// Alignment of the (possibly truncated) address text within its box.
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? context.appColors.secondary;
    final textStyle =
        style ?? context.bullType.body.copyWith(fontWeight: FontWeight.w500);
    final effectiveStyle = textStyle.copyWith(
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
        BullSnackBar.show(context, message: context.loc.copiedToClipboard);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final truncated = _fitToWidth(
            data,
            effectiveStyle,
            constraints.maxWidth,
          );
          final label = BullText(
            truncated,
            style: effectiveStyle,
            maxLines: 1,
            overflow: TextOverflow.clip,
            textAlign: textAlign,
          );
          return constraints.minHeight == 0
              ? label
              : Align(alignment: Alignment.centerLeft, child: label);
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

  static Future<String?> _getExplorerUrlFor(
    String data,
    MempoolLinks links,
  ) async {
    final parsed = await Satoshifier.tryParse(data);
    final (address, network) = switch (parsed) {
      BitcoinAddress(:final address, :final network) ||
      LiquidAddress(:final address, :final network) ||
      Bip21(:final address, :final network) => (address, network),
      _ => (null, null),
    };
    final primitives.Network? concrete = switch (network) {
      Network.bitcoinMainnet => BitcoinNetwork.mainnet,
      Network.bitcoinTestnet => BitcoinNetwork.testnet,
      Network.bitcoinSignet => BitcoinNetwork.signet,
      Network.bitcoinRegtest => BitcoinNetwork.regtest,
      Network.liquidMainnet => LiquidNetwork.mainnet,
      Network.liquidTestnet => LiquidNetwork.testnet,
      Network.liquidRegtest => LiquidNetwork.regtest,
      null => null,
    };
    if (address == null ||
        concrete == null ||
        !NetworkCapabilities.supports(
          concrete,
          NetworkCapability.publicExplorer,
        )) {
      return null;
    }
    final link = await links.address(address, network: concrete);
    return link.fold((uri) => uri.toString(), (_) => null);
  }

  /// Opens the address detail dialog without needing a rendered
  /// [AddressViewer]. Use from a wrapper (e.g. a tappable tile) so the
  /// whole region around the address triggers the same flow.
  static Future<void> showDetail(
    BuildContext context, {
    required String data,
    String? clipboardText,
  }) {
    final links = context.read<MempoolLinks>();
    return BullDialog.show<void>(
      context: context,
      padding: EdgeInsets.zero,
      builder: (dialogContext) => _AddressDetailSheet(
        data: data,
        clipboardText: clipboardText ?? data,
        dialogContext: dialogContext,
        getExplorerUrl: () => _getExplorerUrlFor(data, links),
      ),
    );
  }
}

class _AddressDetailSheet extends StatefulWidget {
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

  @override
  State<_AddressDetailSheet> createState() => _AddressDetailSheetState();
}

class _AddressDetailSheetState extends State<_AddressDetailSheet> {
  static const int _groupSize = 4;

  late final Future<String?> _explorerUrl;
  late bool _showUri;
  late final bool _hasBip21;

  @override
  void initState() {
    super.initState();
    _explorerUrl = widget.getExplorerUrl();
    _hasBip21 = widget.clipboardText != widget.data;
    _showUri = _hasBip21;
  }

  String get _activeText => _showUri ? widget.clipboardText : widget.data;

  List<String> _groupsOf(String text) {
    final groups = <String>[];
    for (int i = 0; i < text.length; i += _groupSize) {
      final end = i + _groupSize > text.length ? text.length : i + _groupSize;
      groups.add(text.substring(i, end));
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
          if (_hasBip21)
            BullSegmented(
              items: {
                context.loc.viewerAddressTab,
                context.loc.viewerPaymentUriTab,
              },
              initialValue: _showUri
                  ? context.loc.viewerPaymentUriTab
                  : context.loc.viewerAddressTab,
              onSelected: (selected) {
                setState(
                  () => _showUri = selected == context.loc.viewerPaymentUriTab,
                );
              },
            )
          else
            BullText(
              context.loc.addressViewerTitle,
              style: context.bullType.label,
              color: context.appColors.onSurface,
            ),
          const Gap(16),
          _buildBody(context),
          const Gap(24),
          _buildCopyAction(context),
          FutureBuilder<String?>(
            future: _explorerUrl,
            builder: (context, snapshot) => _showUri || snapshot.data == null
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      const Gap(16),
                      _buildCopyLinkAction(context),
                      const Gap(16),
                      _buildOpenLinkAction(context),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_showUri) {
      final uri = _activeText;
      final address = widget.data;
      final addressIdx = uri.indexOf(address);
      final baseStyle = context.bullType.body
          .copyWith(fontWeight: FontWeight.w500)
          .copyWith(color: context.appColors.secondary, letterSpacing: 1.2);
      // Highlight the bare address embedded inside the BIP21 URI so the
      // user can spot it at a glance.
      if (addressIdx == -1) {
        return SelectableText.rich(
          TextSpan(text: uri, style: baseStyle),
          textAlign: TextAlign.center,
        );
      }
      return SelectableText.rich(
        TextSpan(
          style: baseStyle,
          children: [
            if (addressIdx > 0) TextSpan(text: uri.substring(0, addressIdx)),
            TextSpan(
              text: address,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (addressIdx + address.length < uri.length)
              TextSpan(text: uri.substring(addressIdx + address.length)),
          ],
        ),
        textAlign: TextAlign.center,
      );
    }

    final groups = _groupsOf(_activeText);
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (int i = 0; i < groups.length; i++)
          Text(
            groups[i],
            style: context.bullType.body
                .copyWith(fontWeight: FontWeight.w500)
                .copyWith(
                  color: i.isOdd
                      ? context.appColors.textMuted
                      : context.appColors.secondary,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [const FontFeature.tabularFigures()],
                  letterSpacing: 1.2,
                ),
          ),
      ],
    );
  }

  Widget _buildCopyAction(BuildContext context) {
    return BullViewerActionButton(
      icon: Icons.copy,
      label: context.loc.viewerTapToCopy,
      onTap: () {
        Clipboard.setData(ClipboardData(text: _activeText));
        Navigator.of(widget.dialogContext).pop();
        BullSnackBar.show(
          widget.dialogContext,
          message: widget.dialogContext.loc.copiedToClipboard,
        );
      },
    );
  }

  Widget _buildCopyLinkAction(BuildContext context) {
    return BullViewerActionButton(
      icon: Icons.link,
      label: context.loc.viewerCopyLink,
      onTap: () async {
        final url = await _explorerUrl;
        if (url == null) return;
        Clipboard.setData(ClipboardData(text: url));
        if (widget.dialogContext.mounted) {
          Navigator.of(widget.dialogContext).pop();
          BullSnackBar.show(
            widget.dialogContext,
            message: widget.dialogContext.loc.copiedToClipboard,
          );
        }
      },
    );
  }

  Widget _buildOpenLinkAction(BuildContext context) {
    return BullViewerActionButton(
      icon: Icons.open_in_new,
      label: context.loc.viewerViewInExplorer,
      onTap: () async {
        final url = await _explorerUrl;
        if (url == null) return;
        if (widget.dialogContext.mounted) {
          Navigator.of(widget.dialogContext).pop();
        }
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      },
    );
  }
}
