import 'package:bb_mobile/core/recoverbull/domain/entity/backup_provider_type.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/cards/provider_cart.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class BackupProviderSelector extends StatelessWidget {
  final void Function(BackupProviderType provider) onProviderSelected;
  final String? description;

  const BackupProviderSelector({
    super.key,
    required this.onProviderSelected,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (description != null) ...[
          BBText(description!, style: context.font.bodySmall),
          const Gap(20),
        ],
        for (final provider in BackupProviderType.values.where(
          (p) => p != BackupProviderType.iCloud,
        )) ...[
          ProviderCard(
            provider: provider,
            onTap: () => onProviderSelected(provider),
          ),
          const Gap(16),
        ],
      ],
    );
  }
}
