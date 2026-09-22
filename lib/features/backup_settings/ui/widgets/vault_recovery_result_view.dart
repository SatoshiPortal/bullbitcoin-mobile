import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class VaultRecoveryResultView extends StatelessWidget {
  final VaultBackupRecovery result;
  const VaultRecoveryResultView({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final vaults =
        result.inspection.snapshot?.vaults ?? const <BullVaultBackupEntry>[];
    final wallets = result.inspection.snapshot?.manifest.wallets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          !result.complete
              ? loc.vaultRecoveryIncomplete
              : vaults.isEmpty
              ? loc.vaultRecoveryNone
              : loc.vaultRecoveryComplete,
        ),
        for (final vault in vaults)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    wallets
                            ?.where((w) => w.reference == vault.reference)
                            .firstOrNull
                            ?.label ??
                        vault.reference,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(switch (vault.recoveryPackage.policy.network) {
                    Network.bitcoinMainnet => loc.mempoolNetworkBitcoinMainnet,
                    Network.bitcoinTestnet => loc.mempoolNetworkBitcoinTestnet,
                    Network.liquidMainnet => loc.mempoolNetworkLiquidMainnet,
                    Network.liquidTestnet => loc.mempoolNetworkLiquidTestnet,
                  }),
                  Text(
                    loc.bullVaultGeneration(
                      vault.recoveryPackage.policy.vaultGeneration + 1,
                    ),
                  ),
                  if (result.wallets.walletReferences[vault.reference]
                      case final id?)
                    Wrap(
                      children: [
                        TextButton(
                          onPressed: () => context.pushNamed(
                            BullVaultFacade.settingsRouteName,
                            pathParameters: {'walletId': id},
                          ),
                          child: Text(loc.vaultRecoveryOpenVault),
                        ),
                        TextButton(
                          onPressed: () => context.pushNamed(
                            BullVaultFacade.cosignerRouteName,
                            pathParameters: {'walletId': id},
                          ),
                          child: Text(loc.bullVaultImportCosigner),
                        ),
                      ],
                    )
                  else
                    Text(loc.dataBackupWalletNotRecovered),
                ],
              ),
            ),
          ),
        Text(loc.vaultRecoveryNoSpendDisclosure),
      ],
    );
  }
}
