import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/entities/backup_settings_snapshot.dart';
import 'package:bb_mobile/features/backup_settings/domain/wallet_metadata_backup_settings_mapping.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/public/wallet_metadata_backup_facade.dart';
import 'package:meta/meta.dart';

class DeleteRemoteWalletMetadataBackupUsecase {
  final WalletMetadataBackupFacade _metadataBackup;

  const DeleteRemoteWalletMetadataBackupUsecase(this._metadataBackup);

  @useResult
  Future<Result<WalletMetadataBackupSettingsSnapshot, BackupSettingsFailure>>
  execute() async {
    final deleted = await _metadataBackup.deleteRemoteBackup();
    if (deleted case Err(:final failure)) {
      return Err(mapWalletMetadataBackupFailure(failure));
    }
    final state = await _metadataBackup.getState();
    return switch (state) {
      Ok(:final value) => Ok(mapWalletMetadataBackupSettings(value)),
      Err(:final failure) => Err(mapWalletMetadataBackupFailure(failure)),
    };
  }
}
