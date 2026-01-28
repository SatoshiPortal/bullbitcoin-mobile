import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitaxe/domain/entities/system_info.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class PoolConfigWidget extends StatelessWidget {
  const PoolConfigWidget({super.key, required this.systemInfo});

  final SystemInfo systemInfo;

  @override
  Widget build(BuildContext context) {
    final primaryPool = systemInfo.primaryPool;
    final bitcoinAddress = primaryPool.bitcoinAddress;

    return Card(
      color: context.appColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(
              builder: (context) {
                return BBText(
                  'Pool',
                  style: context.font.headlineSmall,
                  color: context.appColors.text,
                );
              },
            ),
            const Gap(16),
            _ConfigRow(
              label: 'URL',
              value: primaryPool.formattedAddress,
              context: context,
            ),
            const Gap(12),
            if (bitcoinAddress != null)
              _ConfigRow(
                label: 'User',
                value: primaryPool.stratumUser,
                context: context,
                highlight: true,
              ),
            if (bitcoinAddress != null) ...[
              const Gap(12),
              BBText(
                'Mining rewards will be sent to your wallet address.',
                style: context.font.bodySmall,
                color: context.appColors.textMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  const _ConfigRow({
    required this.label,
    required this.value,
    required this.context,
    this.highlight = false,
  });

  final String label;
  final String value;
  final BuildContext context;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText(
          label,
          style: this.context.font.bodySmall,
          color: this.context.appColors.textMuted,
        ),
        const Gap(4),
        BBText(
          value,
          style: this.context.font.bodyMedium,
          color: highlight
              ? this.context.appColors.primary
              : this.context.appColors.text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
