import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/entities/backup_settings_snapshot.dart';
import 'package:bb_mobile/features/backup_settings/domain/wallet_metadata_backup_settings_mapping.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/public/wallet_metadata_backup_facade.dart';
import 'package:meta/meta.dart';

class SetWalletMetadataBackupEnabledUsecase {
  final WalletMetadataBackupFacade _metadataBackup;

  const SetWalletMetadataBackupEnabledUsecase(this._metadataBackup);

  @useResult
  Future<Result<WalletMetadataBackupSettingsSnapshot, BackupSettingsFailure>>
  execute({required bool enabled, required bool disclosureAccepted}) async {
    try {
      final currentResult = await _metadataBackup.getState();
      final WalletMetadataBackupState current;
      switch (currentResult) {
        case Ok(:final value):
          current = value;
        case Err(:final failure):
          return Err(mapWalletMetadataBackupFailure(failure));
      }

      if (enabled && !disclosureAccepted) {
        return Ok(mapWalletMetadataBackupSettings(current));
      }

      final result = await _metadataBackup.setEnabled(enabled);
      return switch (result) {
        Ok(:final value) => Ok(mapWalletMetadataBackupSettings(value)),
        Err(:final failure) => Err(mapWalletMetadataBackupFailure(failure)),
      };
    } on Exception catch (error, stack) {
      log.warning(
        'Set wallet metadata backup failed',
        error: StateError(error.runtimeType.toString()),
        trace: stack,
      );
      return Err(BackupSettingsUnexpectedFailure(error.runtimeType.toString()));
    }
  }
}
