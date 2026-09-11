import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_contents.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_vault_entry.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_vaults_section.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/wallet_metadata_backup_failure.dart';
import 'package:meta/meta.dart';

final class GetWalletBackupContentsUsecase {
  final Future<Result<KeychainManifest, WalletBackupFailure>> Function()
  _manifest;
  final Future<List<WalletDefinition>> Function() _definitions;
  final Future<Set<String>> Function() _locallyKeyedWalletIds;
  final Future<Result<WalletMetadataSnapshot, WalletMetadataBackupFailure>>
  Function()
  _metadata;
  final BullVaultBackupSection _vaults;
  final InspectVaultRecoveryPackage _inspectVault;

  const GetWalletBackupContentsUsecase(
    this._manifest,
    this._definitions,
    this._locallyKeyedWalletIds,
    this._metadata, {
    required this._vaults,
    required this._inspectVault,
  });

  @useResult
  Future<Result<WalletBackupContents, WalletBackupFailure>> execute() async {
    try {
      final KeychainManifest manifest;
      switch (await _manifest()) {
        case Ok(:final value):
          manifest = value;
        case Err(:final failure):
          return Err(failure);
      }
      final List<WalletBackupVaultEntry> vaults;
      switch (await _vaults.read()) {
        case Ok(:final value):
          vaults = value;
        case Err(:final failure):
          return Err(failure);
      }
      final definitions = await _definitions();
      final locallyKeyedWalletIds = await _locallyKeyedWalletIds();
      final metadata = await _metadata();
      switch (metadata) {
        case Err(:final failure):
          return Err(
            WalletBackupManifestFailure(failure.runtimeType.toString()),
          );
        case Ok(:final value):
          return Ok(
            buildWalletBackupContents(
              manifest: manifest,
              definitions: definitions,
              locallyKeyedWalletIds: locallyKeyedWalletIds,
              metadata: value,
              vaults: vaults,
              inspectVault: _inspectVault,
            ),
          );
      }
    } on Exception catch (error, trace) {
      log.warning(
        'Failed to read wallet backup contents',
        error: error.runtimeType,
        trace: trace,
      );
      return Err(WalletBackupStorageFailure(error.runtimeType.toString()));
    }
  }
}

/// The user-facing inventory of one backup, from its typed sections.
///
/// Shared by the local read and the read of what the server holds, so both
/// describe a backup the same way. Throws [StateError] on an inventory that
/// contradicts itself.
WalletBackupContents buildWalletBackupContents({
  required KeychainManifest manifest,
  required List<WalletDefinition> definitions,
  required Set<String> locallyKeyedWalletIds,
  required WalletMetadataSnapshot? metadata,
  required List<WalletBackupVaultEntry> vaults,
  required InspectVaultRecoveryPackage inspectVault,
}) {
  final labels = {
    for (final preference in metadata?.walletPreferences ?? const [])
      if (preference.label != null) preference.walletRef: preference.label!,
  };
  final vaultWalletRefs = {for (final vault in vaults) vault.walletRef};
  final wallets = <String, WalletBackupWalletSummary>{};
  for (final entry in manifest.entries) {
    for (final wallet
        in entry.materializations.whereType<KeychainManifestWallet>()) {
      if (wallets.containsKey(wallet.walletId)) {
        throw StateError('Duplicate wallet recovery inventory');
      }
      wallets[wallet.walletId] = WalletBackupWalletSummary(
        label: labels[wallet.walletId] ?? wallet.label,
        network: wallet.network,
        provenance: wallet.provenance,
        keysOnDevice: locallyKeyedWalletIds.contains(wallet.walletId),
        derivationPath: entry.derivationPath,
        descriptor: wallet.descriptor,
        seedPassphraseUsed: wallet.seedPassphraseUsed,
      );
    }
  }
  for (final definition in definitions.where(
    (definition) =>
        definition.network.isBitcoin &&
        !vaultWalletRefs.contains(definition.walletRef),
  )) {
    if (wallets.containsKey(definition.walletRef) ||
        !definition.provenance.backedUpAsDefinition) {
      throw StateError('Conflicting wallet recovery inventory');
    }
    wallets[definition.walletRef] = WalletBackupWalletSummary(
      label: labels[definition.walletRef],
      network: definition.network,
      provenance: definition.provenance,
      keysOnDevice: false,
      descriptor: definition.descriptor,
      signerDevice: definition.signerDevice,
    );
  }
  final summaries = wallets.values.toList(growable: false)
    ..sort(_compareWallets);
  // Lineage then generation, whatever order the snapshot held them in, so the
  // inventory reads the same from this device and from the server.
  final vaultSummaries = <WalletBackupVaultSummary>[];
  for (final vault in [...vaults]..sort(WalletBackupVaultEntry.compare)) {
    final facts = inspectVault(vault.recoveryPackage);
    if (facts == null) {
      throw StateError('Unreadable BullVault recovery package');
    }
    vaultSummaries.add(
      WalletBackupVaultSummary(
        walletRef: vault.walletRef,
        label: labels[vault.walletRef] ?? vault.label,
        status: vault.status,
        network: vault.network,
        lineageId: vault.lineageId,
        vaultGeneration: vault.vaultGeneration,
        descriptor: facts.descriptor,
        birthHeight: facts.birthHeight,
        recoveryPackage: vault.recoveryPackage,
      ),
    );
  }
  return WalletBackupContents(
    wallets: summaries,
    vaults: vaultSummaries,
    labelCount: metadata?.labels.length ?? 0,
    frozenCoinCount: metadata?.frozenOutpoints.length ?? 0,
    walletPreferenceCount: metadata?.walletPreferences.length ?? 0,
    settings: metadata?.settings,
  );
}

int _compareWallets(
  WalletBackupWalletSummary left,
  WalletBackupWalletSummary right,
) {
  final byNetwork = left.network.index.compareTo(right.network.index);
  if (byNetwork != 0) return byNetwork;
  final byProvenance = left.provenance.index.compareTo(right.provenance.index);
  if (byProvenance != 0) return byProvenance;
  return (left.label ?? '').compareTo(right.label ?? '');
}
