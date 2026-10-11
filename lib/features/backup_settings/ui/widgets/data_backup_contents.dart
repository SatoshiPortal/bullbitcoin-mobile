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
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bull_ui/bull_ui.dart' show BullBorderedTile, BullSpacing, Gap;
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
      spacing: BullSpacing.md,
      children: [
        Text(switch (source) {
          DataBackupContentsSource.local => loc.dataBackupSourceLocal,
          DataBackupContentsSource.server => loc.dataBackupSourceServer,
          DataBackupContentsSource.file => loc.dataBackupSourceFile,
        }, style: context.font.titleLarge),
        Text(
          loc.dataBackupPublicContentsExplanation,
          style: context.font.bodyMedium,
        ),
        BullBorderedTile(
          child: _ContentsDetail(
            title: Text(loc.dataBackupSourceFingerprint),
            subtitle: Text(manifest.sourceFingerprint),
          ),
        ),
        const Gap(BullSpacing.xs),
        Text(loc.dataBackupWallets, style: context.font.titleMedium),
        for (final wallet in manifest.wallets)
          _ContentsSection(
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
                _ContentsSection(
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
        _ContentsSection(
          title: Text(loc.bullVaultWalletLabel),
          trailing: Text('${snapshot.vaults.length}'),
          children: [
            for (final vault in snapshot.vaults)
              _ContentsDetail(
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
        _ContentsSection(
          title: Text(loc.bip85Title),
          trailing: Text('${manifest.derivations.length}'),
          children: [
            for (final entry in manifest.derivations)
              _ContentsDetail(
                title: Text(entry.alias ?? entry.path),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: BullSpacing.xs,
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
        _ContentsSection(
          title: Text(loc.settingsNostrKeysTitle),
          trailing: Text('${manifest.nostrKeys.length}'),
          children: [
            for (final key in manifest.nostrKeys)
              _ContentsDetail(
                title: Text(key.purpose),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: BullSpacing.xs,
                  children: [
                    Text(key.description),
                    Text(key.publicKey),
                    Text(key.derivationPath),
                    Text(loc.bip85Index(key.identity)),
                    Text(
                      '${loc.transactionDetailLabelCreatedAt}: ${date(key.createdAt)}',
                    ),
                    Text('${loc.dataBackupUpdatedAt}: ${date(key.updatedAt)}'),
                  ],
                ),
              ),
          ],
        ),
        _ContentsSection(
          title: Text(loc.settingsNostrKeysSystemKeysWarningTitle),
          trailing: Text('${manifest.backupIdentities.length}'),
          children: [
            Text(loc.settingsNostrKeysSystemKeysWarningMessage),
            for (final identity in manifest.backupIdentities)
              _ContentsDetail(
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
        _ContentsSection(
          key: const ValueKey('data-contents-labels'),
          title: Text(loc.coinsLabels),
          trailing: Text('${metadata.labels.length}'),
          children: [
            for (final label in metadata.labels)
              _ContentsDetail(
                title: Text(label.label),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: BullSpacing.xs,
                  children: [
                    Text(switch (label.type) {
                      LabelType.transaction => loc.sendTransactionFallback,
                      LabelType.address => loc.transactionDetailLabelAddress,
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
        _ContentsSection(
          key: const ValueKey('data-contents-frozen'),
          title: Text(loc.coinsFrozen),
          trailing: Text('${metadata.frozenOutputs.length}'),
          children: [
            for (final output in metadata.frozenOutputs)
              _ContentsDetail(
                title: Text('${output.txId}:${output.vout}'),
                subtitle: Text(present(output.walletReference)),
              ),
          ],
        ),
        _ContentsSection(
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
              _ContentsSection(
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: BullSpacing.md,
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
                    _ContentsDetail(title: Text(server.url)),
                    ..._facts([(loc.payPriority, '${server.priority}')]),
                  ],
                ],
              ),
            _heading(context, loc.mempoolSettingsTitle),
            for (final network in settings.mempool)
              _ContentsSection(
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: BullSpacing.md,
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
      _ContentsDetail(title: Text(label), subtitle: Text(value)),
  ];

  static Widget _heading(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.only(top: BullSpacing.md),
    child: Text(label, style: context.font.titleMedium),
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

class _ContentsSection extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final List<Widget> children;

  const _ContentsSection({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => BullBorderedTile(
    padding: EdgeInsets.zero,
    child: ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(
        horizontal: BullSpacing.md,
        vertical: BullSpacing.xs,
      ),
      childrenPadding: const EdgeInsets.all(BullSpacing.md),
      shape: const Border(),
      collapsedShape: const Border(),
      backgroundColor: context.appColors.transparent,
      collapsedBackgroundColor: context.appColors.transparent,
      title: DefaultTextStyle.merge(
        style: context.font.headlineMedium,
        child: Row(
          children: [
            Expanded(child: title),
            if (trailing != null) ...[
              const Gap(BullSpacing.xs),
              DefaultTextStyle.merge(
                style: context.font.bodyMedium,
                child: trailing!,
              ),
            ],
          ],
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: BullSpacing.xs),
              child: DefaultTextStyle.merge(
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.textMuted,
                ),
                child: subtitle!,
              ),
            ),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: BullSpacing.md,
          children: children,
        ),
      ],
    ),
  );
}

class _ContentsDetail extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;

  const _ContentsDetail({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: BullSpacing.xs,
    children: [
      DefaultTextStyle.merge(style: context.font.bodyLarge, child: title),
      if (subtitle != null)
        DefaultTextStyle.merge(
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.textMuted,
          ),
          child: subtitle!,
        ),
    ],
  );
}
