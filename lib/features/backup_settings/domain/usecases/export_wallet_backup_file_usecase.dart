import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/wallet_backup_file_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/wallet_backup_failure_mapper.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:primitives/primitives.dart';

final class ExportWalletBackupFileUsecase {
  final WalletBackupFacade _walletBackup;
  final WalletBackupFileRepository _files;

  const ExportWalletBackupFileUsecase(this._walletBackup, this._files);

  Future<Result<bool, BackupSettingsFailure>> execute({
    required WalletBackupFileProtection protection,
    required bool confirmedUnencrypted,
  }) async {
    final export = await _walletBackup.buildExport(
      protection: protection,
      confirmedUnencrypted: confirmedUnencrypted,
    );
    return switch (export) {
      Err(:final failure) => Err(mapWalletBackupFailure(failure)),
      Ok(:final value) => _files.save(value),
    };
  }
}
