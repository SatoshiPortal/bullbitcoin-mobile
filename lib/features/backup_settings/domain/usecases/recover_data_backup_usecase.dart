import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:meta/meta.dart';

class InspectDataBackupUsecase {
  final WalletBackupFacade _backups;
  const InspectDataBackupUsecase(this._backups);

  @useResult
  Future<Result<WalletBackupInspection, BackupSettingsFailure>>
  execute() async =>
      (await _backups.inspect()).mapErr(BackupSettingsFailure.fromDataBackup);
}

class RecoverDataBackupUsecase {
  final WalletBackupFacade _backups;
  const RecoverDataBackupUsecase(this._backups);

  @useResult
  Future<Result<WalletBackupRecovery, BackupSettingsFailure>> execute(
    WalletBackupInspection inspection, {
    required bool confirmed,
    bool enableAfterRecovery = false,
  }) async {
    if (!confirmed) return const Err(BackupSettingsUnexpectedFailure());
    return (await _backups.recover(
      inspection,
      enableAfterRecovery: enableAfterRecovery,
    )).mapErr(BackupSettingsFailure.fromDataBackup);
  }
}
