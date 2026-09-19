import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:flutter/material.dart';

enum DataBackupContentsSource { local, server, file }

/// The same public inventory view is used before recovery and for inspection.
class DataBackupContents extends StatelessWidget {
  final WalletBackupSnapshot snapshot;
  final DataBackupContentsSource source;
  const DataBackupContents({
    super.key,
    required this.snapshot,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final manifest = snapshot.manifest;
    final metadata = snapshot.metadata;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(switch (source) {
          DataBackupContentsSource.local => loc.dataBackupSourceLocal,
          DataBackupContentsSource.server => loc.dataBackupSourceServer,
          DataBackupContentsSource.file => loc.dataBackupSourceFile,
        }, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Text(loc.dataBackupPublicContentsExplanation),
        ListTile(
          title: Text(loc.dataBackupSourceFingerprint),
          subtitle: Text(manifest.sourceFingerprint),
        ),
        Text(
          loc.dataBackupWallets,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final wallet in manifest.wallets)
          ExpansionTile(
            title: Text(
              wallet.label?.isNotEmpty == true
                  ? wallet.label!
                  : wallet.reference,
            ),
            subtitle: Text(switch (wallet.network) {
              Network.bitcoinMainnet => loc.mempoolNetworkBitcoinMainnet,
              Network.bitcoinTestnet => loc.mempoolNetworkBitcoinTestnet,
              Network.liquidMainnet => loc.mempoolNetworkLiquidMainnet,
              Network.liquidTestnet => loc.mempoolNetworkLiquidTestnet,
            }),
            children: [
              CopyInput(text: wallet.publicDescriptor, maxLines: null),
              for (final signer in wallet.signers)
                ListTile(title: Text(signer.displayFingerprint)),
            ],
          ),
        ExpansionTile(
          title: Text(loc.bullVaultWalletLabel),
          trailing: Text('${snapshot.vaults.length}'),
          children: [
            for (final vault in snapshot.vaults)
              ListTile(
                title: Text(vault.reference),
                subtitle: Text(
                  loc.bullVaultGeneration(
                    vault.recoveryPackage.policy.vaultGeneration + 1,
                  ),
                ),
              ),
          ],
        ),
        ExpansionTile(
          title: Text(loc.bip85Title),
          trailing: Text('${manifest.derivations.length}'),
          children: [
            for (final entry in manifest.derivations)
              ListTile(
                title: Text(entry.alias ?? entry.path),
                subtitle: Text(entry.path),
              ),
          ],
        ),
        ExpansionTile(
          title: Text(loc.settingsNostrKeysTitle),
          trailing: Text('${manifest.nostrKeys.length}'),
          children: [
            for (final key in manifest.nostrKeys)
              ListTile(
                title: Text(key.purpose),
                subtitle: Text(
                  '${key.description}\n${key.publicKey}\n${key.derivationPath}',
                ),
              ),
          ],
        ),
        ExpansionTile(
          title: Text(loc.settingsNostrKeysSystemKeysWarningTitle),
          trailing: Text('${manifest.backupIdentities.length}'),
          children: [
            Text(loc.settingsNostrKeysSystemKeysWarningMessage),
            for (final identity in manifest.backupIdentities)
              ListTile(
                title: Text(identity.publicKey),
                subtitle: Text(identity.derivationSteps.join(' → ')),
              ),
          ],
        ),
        ExpansionTile(
          title: Text(loc.coinsLabels),
          trailing: Text('${metadata.labels.length}'),
          children: [
            for (final label in metadata.labels)
              ListTile(
                title: Text(label.label),
                subtitle: Text(label.reference),
              ),
          ],
        ),
        ExpansionTile(
          title: Text(loc.coinsFrozen),
          trailing: Text('${metadata.frozenOutputs.length}'),
          children: [
            for (final output in metadata.frozenOutputs)
              ListTile(
                title: Text('${output.txId}:${output.vout}'),
                subtitle: Text(output.walletReference ?? ''),
              ),
          ],
        ),
        ExpansionTile(
          title: Text(loc.settingsAppSettingsTitle),
          children: [
            ListTile(
              title: Text(loc.satsBitcoinUnitSettingsLabel),
              subtitle: Text(metadata.settings.app.bitcoinUnit.code),
            ),
            ListTile(
              title: Text(loc.settingsCurrencyTitle),
              subtitle: Text(metadata.settings.app.currency),
            ),
            ListTile(
              title: Text(loc.settingsLanguageTitle),
              subtitle: Text(metadata.settings.app.language.label),
            ),
            Text(loc.dataBackupPortableSettingsExplanation),
          ],
        ),
      ],
    );
  }
}
