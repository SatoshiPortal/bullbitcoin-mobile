import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitaxe/domain/entities/system_info.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class MiningStatusWidget extends StatelessWidget {
  const MiningStatusWidget({super.key, required this.systemInfo});

  final SystemInfo systemInfo;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.appColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BBText(
              'Mining Status',
              style: context.font.headlineSmall,
              color: context.appColors.text,
            ),
            const Gap(16),
            _StatusRow(
              label: 'Hashrate',
              value: systemInfo.formattedHashRate,
              context: context,
            ),
            const Gap(12),
            _StatusRow(
              label: 'ASIC Temperature',
              value: '${systemInfo.temp.toStringAsFixed(1)}°C',
              context: context,
            ),
            const Gap(12),
            _StatusRow(
              label: 'Input Voltage',
              value: '${(systemInfo.voltage / 1000).toStringAsFixed(1)} V',
              context: context,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.context,
  });

  final String label;
  final String value;
  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        BBText(
          label,
          style: this.context.font.bodyMedium,
          color: this.context.appColors.textMuted,
        ),
        BBText(
          value,
          style: this.context.font.bodyLarge,
          color: this.context.appColors.text,
        ),
      ],
    );
  }
}
