import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bull_logger/bull_logger.dart' show log;
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final String copyLabel;

  const WalletDetailCopyField({
    super.key,
    required this.label,
    required this.value,
    required this.copyLabel,
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
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            BBText(
              value,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.onSurface,
              ),
            ),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                log.info('Copied $label to clipboard');
              },
              child: Row(
                mainAxisSize: .min,
                children: [
                  BBText(
                    copyLabel,
                    style: context.font.bodyMedium?.copyWith(
                      color: context.appColors.primary,
                      fontSize: 14,
                    ),
                  ),
                  const Gap(4),
                  Icon(Icons.copy, size: 16, color: context.appColors.primary),
                ],
              ),
            ),
          ],
        ),
      ],
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
