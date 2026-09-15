import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';

final class RetryWalletBackupRecoveryUsecase {
  final WalletBackupFacade _walletBackup;

  const RetryWalletBackupRecoveryUsecase(this._walletBackup);

  Future<WalletBackupRecoveryResult> execute() => _walletBackup.recover();
}
