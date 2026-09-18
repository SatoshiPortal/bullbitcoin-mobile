import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_inventory_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_inventory_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';

final class RestoreWalletInventoryUsecase {
  final WalletInventoryBackupRepository _repository;

  const RestoreWalletInventoryUsecase(this._repository);

  Future<Result<WalletInventoryRecovery, WalletBackupFailure>> execute(
    List<BackupWallet> wallets,
  ) => _repository.restore(wallets);
}
