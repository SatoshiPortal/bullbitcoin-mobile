import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';

class RecoverBullRemoteKeychainUsecase {
  final WalletBackupFacade _walletBackup;

  const RecoverBullRemoteKeychainUsecase(this._walletBackup);

  Future<void> execute({required Set<String> defaultCreatedWalletIds}) async {
    final result = await _walletBackup.recover(
      defaultCreatedWalletIds: defaultCreatedWalletIds,
    );
    if (result.status != WalletBackupRecoveryStatus.noBackup &&
        result.status != WalletBackupRecoveryStatus.restored) {
      log.warning(
        'Optional wallet backup recovery did not complete',
        error: result.status,
      );
    }
  }
}
