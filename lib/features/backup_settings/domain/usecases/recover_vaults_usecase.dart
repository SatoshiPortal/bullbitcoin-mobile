import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:meta/meta.dart';

class RecoverVaultsUsecase {
  final WalletBackupFacade _backups;
  const RecoverVaultsUsecase(this._backups);

  @useResult
  Future<Result<VaultBackupRecovery?, BackupSettingsFailure>> execute({
    String? words,
    bool Function()? abandoned,
  }) async => (await _backups.recoverVaults(
    words: words,
    abandoned: abandoned,
  )).mapErr(BackupSettingsFailure.fromDataBackup);
}
