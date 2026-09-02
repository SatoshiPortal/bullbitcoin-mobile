import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/wallet_backup_failure_mapper.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:primitives/primitives.dart';

final class DeleteWalletBackupUsecase {
  final WalletBackupFacade _walletBackup;

  const DeleteWalletBackupUsecase(this._walletBackup);

  Future<Result<void, BackupSettingsFailure>> execute() async {
    final disabled = await _walletBackup.setEnabled(false);
    if (disabled case Err(:final failure)) {
      return Err(mapWalletBackupFailure(failure));
    }
    return (await _walletBackup.deleteRemoteBackup(
      confirmed: true,
    )).mapErr(mapWalletBackupFailure);
  }
}
