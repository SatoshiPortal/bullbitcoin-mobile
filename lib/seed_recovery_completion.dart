import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';

Future<bool> recoverWalletDataAfterSeedRestore(
  WalletBackupFacade walletBackup, {
  required Set<String> defaultCreatedWalletIds,
}) async {
  try {
    final result = await walletBackup.recover(
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
  } on Exception catch (error, stackTrace) {
    log.warning(
      'Optional wallet backup recovery failed',
      error: error.runtimeType,
      trace: stackTrace,
    );
    return false;
  }
}
