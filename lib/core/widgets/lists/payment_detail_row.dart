import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/address_viewer.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart' show BullDetailsTableItem, BullSnackBar;
import 'package:flutter/material.dart';

class PaymentDetailRow extends StatelessWidget {
  final String title;
  final String? value;
  final String? copyValue;
  final VoidCallback? onTap;
  final bool isAddress;

  const PaymentDetailRow({
    super.key,
    required this.title,
    this.value,
    this.copyValue,
    this.onTap,
    this.isAddress = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = value;
    final action = onTap;
    final Widget? display = text == null
        ? null
        : isAddress
        ? AddressViewer(text, textAlign: TextAlign.end)
        : action == null
        ? null
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: action,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    text,
                    textAlign: TextAlign.end,
                    style: context.font.bodyMedium?.copyWith(
                      color: context.appColors.primary,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: context.appColors.primary,
                ),
              ],
            ),
          );
    return BullDetailsTableItem(
      label: title,
      displayValue: text,
      displayWidget: display,
      copyValue: isAddress ? null : copyValue,
      onCopied: () =>
          BullSnackBar.show(context, message: context.loc.copiedToClipboard),
    );
  }
}
