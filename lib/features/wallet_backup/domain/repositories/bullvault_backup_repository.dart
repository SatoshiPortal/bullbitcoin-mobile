import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/bullvault_backup_entry.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_inventory_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

abstract interface class BullVaultBackupRepository {
  Stream<void> get changes;
  @useResult
  Future<Result<List<BullVaultBackupEntry>, WalletBackupFailure>> capture(
    Map<String, String> references,
  );
  @useResult
  Future<Result<WalletInventoryRecovery, WalletBackupFailure>> restore(
    List<BullVaultBackupEntry> entries,
    List<BackupWallet> wallets,
  );
}
