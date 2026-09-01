import 'package:bull_recoverbull/src/domain/entities/vault_provider.dart';
import 'package:flutter/material.dart';
import 'package:bull_recoverbull/src/ui/widgets/provider_cart.dart';
import 'package:bull_recoverbull/src/ui/support.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

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
      crossAxisAlignment: .start,
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
