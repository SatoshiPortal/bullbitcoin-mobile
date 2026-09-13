import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/dialog/blurred_dialog.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/qr_display_widget.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

class WalletDetailInfoField extends StatelessWidget {
  final String label;
  final String value;

  const WalletDetailInfoField({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        BBText(
          label,
          style: context.font.bodyLarge?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(4),
        BBText(
          value,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.onSurface,
          ),
        ),
      ],
    );
  }
}

class WalletDetailCopyField extends StatelessWidget {
  final String label;
  final String value;
  final String? clipboardText;
  final bool showQr;

  const WalletDetailCopyField({
    super.key,
    required this.label,
    required this.value,
    this.clipboardText,
    this.showQr = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        Row(
          children: [
            Expanded(
              child: BBText(
                label,
                style: context.font.bodyLarge?.copyWith(
                  color: context.appColors.textMuted,
                ),
              ),
            ),
            if (showQr)
              IconButton(
                tooltip: context.loc.receiveQRCode,
                icon: const Icon(Icons.qr_code),
                onPressed: () => _showQr(context),
              ),
          ],
        ),
        const Gap(4),
        CopyInput(text: value, clipboardText: clipboardText),
      ],
    );
  }

  void _showQr(BuildContext context) {
    final payload = clipboardText ?? value;
    BlurredDialog.show<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appColors.surface,
        title: Text(label),
        content: SizedBox(
          width: 300,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: QrDisplayWidget(data: payload),
                ),
                const Gap(16),
                CopyInput(text: payload),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.loc.closeDialogButton),
          ),
        ],
      ),
    );
  }
}

class WalletDetailActionField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const WalletDetailActionField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      child: Material(
        color: context.appColors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                Expanded(
                  child: BBText(
                    label,
                    style: context.font.bodyLarge?.copyWith(
                      color: context.appColors.textMuted,
                    ),
                  ),
                ),
                const Gap(12),
                BBText(
                  value,
                  style: context.font.bodyMedium?.copyWith(
                    color: onTap == null
                        ? context.appColors.textMuted
                        : context.appColors.primary,
                  ),
                ),
                if (onTap != null) ...[
                  const Gap(4),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: context.appColors.primary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
