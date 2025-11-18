import 'package:bb_mobile/core/recoverbull/domain/entity/vault_provider.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/cards/provider_cart.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class RecoverbullVaultProviderSelector extends StatelessWidget {
  final void Function(VaultProvider provider) onProviderSelected;
  final String? description;

  const RecoverbullVaultProviderSelector({
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
        for (final provider in VaultProvider.values.where(
          (p) => p != VaultProvider.iCloud,
        )) ...[
          ProviderCard(
            provider: provider,
            onTap: () => onProviderSelected(provider),
          ),
          const Gap(12),
        ],
      ],
    );
  }
}
