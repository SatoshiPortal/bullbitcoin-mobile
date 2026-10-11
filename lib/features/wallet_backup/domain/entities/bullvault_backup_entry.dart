import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';

/// An add-on to the wallet inventory. Annotations and labels remain there;
/// verification dates describe this installation and are never portable.
final class BullVaultBackupEntry {
  final String reference;
  final BullVaultLifecycleStatus status;
  final BullVaultRecoveryPackage recoveryPackage;

  BullVaultBackupEntry({
    required this.reference,
    required this.status,
    required this.recoveryPackage,
  }) {
    if (reference.isEmpty || reference.length > 1024) {
      throw const FormatException('Invalid vault reference');
    }
  }

  static void validateInventory(
    List<BullVaultBackupEntry> entries,
    List<BackupWallet> wallets,
  ) {
    final byReference = {for (final entry in entries) entry.reference: entry};
    final inventory = {for (final wallet in wallets) wallet.reference: wallet};
    if (byReference.length != entries.length ||
        inventory.length != wallets.length ||
        entries
                .map(
                  (entry) => (
                    entry.recoveryPackage.policy.network,
                    entry.recoveryPackage.policy.lineageId,
                    entry.recoveryPackage.policy.vaultGeneration,
                  ),
                )
                .toSet()
                .length !=
            entries.length) {
      throw const FormatException('Duplicate vault inventory');
    }
    for (final entry in entries) {
      final policy = entry.recoveryPackage.policy;
      final wallet = inventory[entry.reference];
      if (wallet == null ||
          wallet.network != policy.network ||
          wallet.publicDescriptor != policy.descriptor) {
        throw const FormatException('Vault does not match wallet inventory');
      }
      final previous = entry.recoveryPackage.previousVaultId;
      if (previous != null) {
        final predecessor = byReference[previous]?.recoveryPackage.policy;
        // Strictly decreasing generations also exclude cycles. Recovery makes
        // one finite pass over the byte-bounded snapshot, never follows a loop.
        if (predecessor == null ||
            predecessor.lineageId != policy.lineageId ||
            predecessor.network != policy.network ||
            predecessor.vaultGeneration >= policy.vaultGeneration) {
          throw const FormatException('Incomplete vault lineage');
        }
      }
    }
  }
}
