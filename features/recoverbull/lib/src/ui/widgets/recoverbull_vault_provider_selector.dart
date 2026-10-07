import 'package:flutter/material.dart';
import '../../domain/entities/vault_provider.dart';
import 'bull_aliases.dart';
import 'provider_cart.dart';
import 'with_bull_theme.dart';

class RecoverbullVaultProviderSelector extends StatelessWidget {
  final void Function(VaultProvider provider) onProviderSelected;
  final String? description;
  final bool enabled;

  const RecoverbullVaultProviderSelector({
    super.key,
    required this.onProviderSelected,
    this.description,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (description != null) ...[
        BBText(description!, style: context.font.bodySmall),
        const SizedBox(height: 20),
      ],
      for (final provider in VaultProvider.values.where(
        (provider) => provider != VaultProvider.iCloud,
      )) ...[
        ProviderCard(
          provider: provider,
          enabled: enabled,
          onTap: () => onProviderSelected(provider),
        ),
        const SizedBox(height: 12),
      ],
    ],
  );
}
