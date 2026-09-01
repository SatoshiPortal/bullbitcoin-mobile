import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';

class RecoverBullRemoteKeychainUsecase {
  final WalletBackupFacade _walletBackup;

  const RecoverBullRemoteKeychainUsecase(this._walletBackup);

  Future<bool> execute({required Set<String> defaultCreatedWalletIds}) async {
    final result = await _walletBackup.recover(
      defaultCreatedWalletIds: defaultCreatedWalletIds,
    );
    final complete =
        result.status == WalletBackupRecoveryStatus.noBackup ||
        result.status == WalletBackupRecoveryStatus.restored;
    if (!complete) {
      log.warning(
        'Optional wallet backup recovery did not complete',
        error: result.status,
      );
    }
    return complete;
  }
}
