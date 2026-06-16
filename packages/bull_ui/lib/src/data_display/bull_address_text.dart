import 'package:bull_ui/src/theme/bull_icon.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Truncated address with tap-to-copy. **New primitive** — deliberately not a
/// port of `address_viewer.dart`, which depends on feature/app services
/// (`Satoshifier`, `MempoolUrlBuilder`, `url_launcher`) that must not enter a
/// UI package.
///
/// Takes the **full** address; displays it truncated to `8…8` (per §14) and
/// copies the full string to the clipboard, then invokes [onCopied].
class BullAddressText extends StatelessWidget {
  const BullAddressText({
    super.key,
    required this.address,
    this.onCopied,
    this.head = 8,
    this.tail = 8,
  });

  /// The full address string. Truncated for display, copied in full.
  final String address;

  /// Invoked after the full address is copied to the clipboard.
  final VoidCallback? onCopied;

  /// Leading characters kept in the truncated display.
  final int head;

  /// Trailing characters kept in the truncated display.
  final int tail;

  String get _truncated {
    if (address.length <= head + tail + 1) return address;
    return '${address.substring(0, head)}…${address.substring(address.length - tail)}';
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: address));
    onCopied?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Semantics(
      button: true,
      label: address,
      hint: 'Copy address',
      child: GestureDetector(
        onTap: _copy,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _truncated,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colors.textMuted),
              ),
            ),
            const SizedBox(width: 4),
            BullIcon(BullIcons.contentCopy, size: 12, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}
