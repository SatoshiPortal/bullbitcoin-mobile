import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/entities/backup_settings_snapshot.dart';
import 'package:bb_mobile/features/backup_settings/domain/wallet_metadata_backup_settings_mapping.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/public/wallet_metadata_backup_facade.dart';
import 'package:meta/meta.dart';

class BackupWalletMetadataNowUsecase {
  final WalletMetadataBackupFacade _metadataBackup;

  const BackupWalletMetadataNowUsecase(this._metadataBackup);

  @useResult
  Future<Result<WalletMetadataBackupNowResult, BackupSettingsFailure>>
  execute() async {
    try {
      final publicationResult = await _metadataBackup.backupNow();
      final WalletMetadataPublishOutcome publication;
      switch (publicationResult) {
        case Ok(:final value):
          publication = value;
        case Err(:final failure):
          return Err(mapWalletMetadataBackupFailure(failure));
      }
      final stateResult = await _metadataBackup.getState();
      final WalletMetadataBackupState state;
      switch (stateResult) {
        case Ok(:final value):
          state = value;
        case Err(:final failure):
          return Err(mapWalletMetadataBackupFailure(failure));
      }
      final status = switch (publication.status) {
        WalletMetadataPublishStatus.stored =>
          WalletMetadataBackupNowStatus.saved,
        WalletMetadataPublishStatus.unchanged ||
        WalletMetadataPublishStatus.initialEmpty =>
          WalletMetadataBackupNowStatus.unchanged,
        WalletMetadataPublishStatus.notReady =>
          WalletMetadataBackupNowStatus.notReady,
      };
      return Ok(
        WalletMetadataBackupNowResult(
          status: status,
          settings: mapWalletMetadataBackupSettings(state),
        ),
      );
    } on Exception catch (error, stack) {
      log.warning(
        'Manual wallet metadata backup failed',
        error: StateError(error.runtimeType.toString()),
        trace: stack,
      );
      return Err(BackupSettingsUnexpectedFailure(error.runtimeType.toString()));
    }
  }
}
