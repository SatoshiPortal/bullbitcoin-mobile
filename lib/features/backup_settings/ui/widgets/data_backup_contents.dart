import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
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
    final settings = metadata.settings;
    String flag(bool value) =>
        value ? loc.wizardMissionYes : loc.wizardMissionNo;
    String present(String? value) =>
        value == null || value.isEmpty ? loc.dataBackupNotRecorded : value;
    String date(DateTime? value) =>
        value?.toUtc().toIso8601String() ?? loc.dataBackupNotRecorded;
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
              ..._facts([
                (loc.dataBackupWalletReference, wallet.reference),
                (loc.dataBackupDefaultWallet, flag(wallet.isDefault)),
                (loc.dataBackupHiddenWallet, flag(wallet.isHidden)),
                (loc.dataBackupBirthday, date(wallet.birthday)),
              ]),
              CopyInput(text: wallet.publicDescriptor, maxLines: null),
              for (final signer in wallet.signers)
                ExpansionTile(
                  title: Text(signer.displayFingerprint),
                  children: [
                    ..._facts([
                      (
                        loc.dataBackupRecordedSigner,
                        switch (signer.signer) {
                          SignerEntity.local => loc.dataBackupSourceDevice,
                          SignerEntity.remote =>
                            loc.walletDetailsExternalSignerLabel,
                          SignerEntity.none =>
                            loc.walletDetailsUnassignedSignerLabel,
                        },
                      ),
                      (
                        loc.walletDetailsSignerDeviceLabel,
                        present(signer.signerDevice?.displayName),
                      ),
                      (
                        loc.bullVaultRegistrationNameLabel,
                        present(signer.registrationName),
                      ),
                    ]),
                    for (final key in signer.descriptorKeys) ...[
                      ..._facts([
                        (
                          loc.dataBackupMasterFingerprint,
                          key.masterFingerprint,
                        ),
                        (
                          loc.walletDetailsDerivationPathLabel,
                          present(key.derivationPath),
                        ),
                        (
                          loc.dataBackupDescriptorPath,
                          present(key.descriptorPath),
                        ),
                        (
                          loc.bullVaultPassphraseRequired,
                          flag(key.requiresPassphrase),
                        ),
                      ]),
                      CopyInput(text: key.xpub, maxLines: null),
                    ],
                  ],
                ),
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
                  '${loc.bullVaultGeneration(vault.recoveryPackage.policy.vaultGeneration + 1)} · ${switch (vault.status) {
                    BullVaultLifecycleStatus.pending => loc.coreSwapsStatusPending,
                    BullVaultLifecycleStatus.active => loc.dataBackupStatusActive,
                    BullVaultLifecycleStatus.migrating => loc.dataBackupStatusMigrating,
                    BullVaultLifecycleStatus.cancelled => loc.dataBackupStatusCancelled,
                  }}',
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
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.path),
                    Text(loc.bip85Index(entry.index)),
                    Text(entry.application.name),
                    Text(switch (entry.status) {
                      Bip85Status.active => loc.dataBackupStatusActive,
                      Bip85Status.inactive => loc.dataBackupStatusInactive,
                      Bip85Status.revoked => loc.dataBackupStatusRevoked,
                    }),
                  ],
                ),
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
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(key.description),
                    Text(key.publicKey),
                    Text(key.derivationPath),
                    Text(loc.bip85Index(key.identity)),
                    Text(
                      '${loc.transactionLabelCreatedAt}: ${date(key.createdAt)}',
                    ),
                    Text('${loc.dataBackupUpdatedAt}: ${date(key.updatedAt)}'),
                  ],
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
                title: Text(switch (identity.kind) {
                  BackupIdentityKind.artifact =>
                    loc.settingsNostrKeysArtifactIdentity,
                  BackupIdentityKind.server =>
                    loc.settingsNostrKeysServerIdentity,
                }),
                subtitle: Text(
                  '${identity.publicKey}\n${identity.derivationSteps.join(' → ')}',
                ),
              ),
          ],
        ),
        ExpansionTile(
          key: const ValueKey('data-contents-labels'),
          title: Text(loc.coinsLabels),
          trailing: Text('${metadata.labels.length}'),
          children: [
            for (final label in metadata.labels)
              ListTile(
                title: Text(label.label),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(switch (label.type) {
                      LabelType.transaction => loc.sendTransactionFallback,
                      LabelType.address => loc.transactionLabelAddress,
                      LabelType.input => loc.dataBackupLabelInput,
                      LabelType.output => loc.dataBackupLabelOutput,
                      LabelType.publicKey => loc.walletDetailsPubkeyLabel,
                      LabelType.extendedPublicKey =>
                        loc.importWatchOnlyExtendedPublicKey,
                    }),
                    Text(label.reference),
                    if (label.origin case final origin?) Text(origin),
                  ],
                ),
              ),
          ],
        ),
        ExpansionTile(
          key: const ValueKey('data-contents-frozen'),
          title: Text(loc.coinsFrozen),
          trailing: Text('${metadata.frozenOutputs.length}'),
          children: [
            for (final output in metadata.frozenOutputs)
              ListTile(
                title: Text('${output.txId}:${output.vout}'),
                subtitle: Text(present(output.walletReference)),
              ),
          ],
        ),
        ExpansionTile(
          title: Text(loc.settingsAppSettingsTitle),
          children: [
            ..._facts([
              (loc.satsBitcoinUnitSettingsLabel, settings.app.bitcoinUnit.code),
              (loc.settingsCurrencyTitle, settings.app.currency),
              (loc.settingsLanguageTitle, settings.app.language.label),
              (
                loc.settingsThemeTitle,
                switch (settings.app.themeMode) {
                  AppThemeMode.light => loc.themeLight,
                  AppThemeMode.dark => loc.themeDark,
                  AppThemeMode.system => loc.themeSystem,
                },
              ),
              (loc.dataBackupHideAmounts, flag(settings.app.hideAmounts)),
            ]),
            _heading(context, loc.autoswapSettingsTitle),
            ..._facts([
              (loc.autoswapEnableToggleLabel, flag(settings.autoSwap.enabled)),
              (
                loc.autoswapTargetBalanceLabel,
                '${settings.autoSwap.balanceThresholdSats} sats',
              ),
              (
                loc.autoswapMaximumBalanceLabel,
                '${settings.autoSwap.triggerBalanceSats} sats',
              ),
              (
                loc.autoswapMaxFeeLabel,
                '${settings.autoSwap.feeThresholdPercent}%',
              ),
              (
                loc.autoswapAlwaysBlockLabel,
                flag(settings.autoSwap.alwaysBlock),
              ),
              (
                loc.autoswapRecipientWalletLabel,
                present(settings.autoSwap.recipientWalletReference),
              ),
            ]),
            _heading(context, loc.settingsPayjoinTitle),
            ..._facts([
              (loc.settingsPayjoinEnabledLabel, flag(settings.payjoin.enabled)),
              (
                loc.settingsPayjoinMinAmountTitle,
                '${settings.payjoin.minimumAmount.value} sats',
              ),
              (
                loc.settingsPayjoinExpireTitle,
                loc.dataBackupSecondsValue(
                  settings.payjoin.sessionLifetime.inSeconds,
                ),
              ),
            ]),
            _heading(context, loc.electrumTitle),
            for (final network in settings.electrum)
              ExpansionTile(
                key: ValueKey('data-contents-electrum-${network.network.name}'),
                title: Text(
                  _network(
                    context,
                    isLiquid: network.network.isLiquid,
                    isTestnet: network.network.isTestnet,
                  ),
                ),
                children: [
                  Column(
                    key: ValueKey(
                      'data-contents-electrum-settings-${network.network.name}',
                    ),
                    children: _facts([
                      (
                        loc.electrumValidateDomain,
                        flag(network.validateDomain),
                      ),
                      (loc.electrumStopGap, '${network.stopGap}'),
                      (loc.electrumTimeout, '${network.timeout}'),
                      (loc.electrumRetryCount, '${network.retry}'),
                    ]),
                  ),
                  if (network.servers.isEmpty) Text(loc.dataBackupNoEntries),
                  for (final server in network.servers) ...[
                    ListTile(title: Text(server.url)),
                    ..._facts([(loc.payPriority, '${server.priority}')]),
                  ],
                ],
              ),
            _heading(context, loc.mempoolSettingsTitle),
            for (final network in settings.mempool)
              ExpansionTile(
                key: ValueKey('data-contents-mempool-${network.network.name}'),
                title: Text(
                  _network(
                    context,
                    isLiquid: network.network.isLiquid,
                    isTestnet: network.network.isTestnet,
                  ),
                ),
                children: [
                  Column(
                    key: ValueKey(
                      'data-contents-mempool-settings-${network.network.name}',
                    ),
                    children: _facts([
                      (
                        loc.mempoolSettingsCustomServer,
                        present(network.customUrl),
                      ),
                      (
                        loc.mempoolSettingsUseForFeeEstimation,
                        flag(network.useForFeeEstimation),
                      ),
                    ]),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  static List<Widget> _facts(List<(String, String)> facts) => [
    for (final (label, value) in facts)
      ListTile(title: Text(label), subtitle: Text(value)),
  ];

  static Widget _heading(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(label, style: Theme.of(context).textTheme.titleMedium),
  );

  static String _network(
    BuildContext context, {
    required bool isLiquid,
    required bool isTestnet,
  }) => switch ((isLiquid, isTestnet)) {
    (false, false) => context.loc.mempoolNetworkBitcoinMainnet,
    (false, true) => context.loc.mempoolNetworkBitcoinTestnet,
    (true, false) => context.loc.mempoolNetworkLiquidMainnet,
    (true, true) => context.loc.mempoolNetworkLiquidTestnet,
  };
}
