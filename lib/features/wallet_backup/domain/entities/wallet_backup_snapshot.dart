import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/bullvault_backup_entry.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_metadata_backup.dart';

final class WalletBackupSnapshot {
  final KeychainManifest manifest;
  final WalletMetadataBackup metadata;
  final List<BullVaultBackupEntry> vaults;

  WalletBackupSnapshot({
    required this.manifest,
    required this.metadata,
    required List<BullVaultBackupEntry> vaults,
  }) : vaults = List.unmodifiable(vaults) {
    BullVaultBackupEntry.validateInventory(vaults, manifest.wallets);
    final references = manifest.wallets
        .map((wallet) => wallet.reference)
        .toSet();
    final recipient = metadata.settings.autoSwap.recipientWalletReference;
    if (metadata.frozenOutputs.any(
          (output) =>
              output.walletReference != null &&
              !references.contains(output.walletReference),
        ) ||
        recipient != null && !references.contains(recipient)) {
      throw const FormatException('Missing wallet referenced by metadata');
    }
  }
}
