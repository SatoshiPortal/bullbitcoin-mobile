import 'package:bull_ui/bull_ui.dart';
import '../../domain/entities/vault_provider.dart';
import 'provider_cart.dart';

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
        BullText(description!, style: context.bullText.bodySmall),
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
