import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_vault_entry.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

final class WalletVaultsRecoveryResult {
  final int restoredCount;
  final int skippedCount;
  final int failedCount;
  final List<String> createdWalletRefs;

  WalletVaultsRecoveryResult({
    required this.restoredCount,
    required this.skippedCount,
    required this.failedCount,
    required List<String> createdWalletRefs,
  }) : createdWalletRefs = List.unmodifiable(createdWalletRefs);
}

/// The vaults section's owner-facing contract, mirroring the definitions one.
abstract interface class BullVaultBackupSection {
  /// Every vault record on this device, read from local state alone. An empty
  /// list leaves the section out of the published snapshot.
  @useResult
  Future<Result<List<WalletBackupVaultEntry>, WalletBackupFailure>> read();

  /// Replays recovery packages through the vault feature's own restore.
  ///
  /// Entries for another network than the running environment are skipped and
  /// not counted (D4): they stay in the backup for a recovery on that network.
  @useResult
  Future<Result<WalletVaultsRecoveryResult, WalletBackupFailure>> recover(
    List<WalletBackupVaultEntry> entries, {
    DateTime? deadline,
  });
}
