import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:meta/meta.dart';

class ExportDataBackupFileUsecase {
  final WalletBackupFacade _backups;
  const ExportDataBackupFileUsecase(this._backups);
  @useResult
  Future<Result<bool, BackupSettingsFailure>> execute(
    WalletBackupFileFormat format, {
    bool confirmed = false,
  }) async => (await _backups.exportFile(
    format,
    confirmed: confirmed,
  )).mapErr(BackupSettingsFailure.fromDataBackup);
}

class InspectDataBackupFileUsecase {
  final WalletBackupFacade _backups;
  const InspectDataBackupFileUsecase(this._backups);
  @useResult
  Future<
    Result<
      ({String source, WalletBackupFileComparison comparison})?,
      BackupSettingsFailure
    >
  >
  execute() async {
    final picked = await _backups.pickFile();
    switch (picked) {
      case Err(:final failure):
        return Err(BackupSettingsFailure.fromDataBackup(failure));
      case Ok(value: null):
        return const Ok(null);
      case Ok(value: final source?):
        // Only a successfully validated file is retained for a later explicit
        // choice. Invalid/raw input never enters presentation state or logs.
        return (await _backups.compareFile(source))
            .map((comparison) => (source: source, comparison: comparison))
            .mapErr(BackupSettingsFailure.fromDataBackup);
    }
  }
}

class RecoverDataBackupFileUsecase {
  final WalletBackupFacade _backups;
  const RecoverDataBackupFileUsecase(this._backups);
  @useResult
  Future<Result<WalletBackupRecovery, BackupSettingsFailure>> execute(
    String file, {
    required WalletBackupFileComparison comparison,
    required WalletBackupImportSource source,
    required bool confirmed,
  }) async {
    if (!confirmed) {
      return const Err(BackupSettingsConfirmationRequiredFailure());
    }
    return (await _backups.recoverFile(
      file,
      comparison: comparison,
      source: source,
      confirmed: confirmed,
    )).mapErr(BackupSettingsFailure.fromDataBackup);
  }
}
