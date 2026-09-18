import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/bullvault_backup_entry.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_inventory_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/bullvault_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';

final class CaptureBullVaultBackupUsecase {
  final BullVaultBackupRepository _repository;
  const CaptureBullVaultBackupUsecase(this._repository);
  Future<Result<List<BullVaultBackupEntry>, WalletBackupFailure>> execute(
    Map<String, String> references,
  ) => _repository.capture(references);
}

final class RestoreBullVaultBackupUsecase {
  final BullVaultBackupRepository _repository;
  const RestoreBullVaultBackupUsecase(this._repository);
  Future<Result<WalletInventoryRecovery, WalletBackupFailure>> execute(
    List<BullVaultBackupEntry> entries,
    List<BackupWallet> wallets,
  ) => _repository.restore(entries, wallets);
}
