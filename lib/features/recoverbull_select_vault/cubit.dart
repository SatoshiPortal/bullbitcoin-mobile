import 'package:bb_mobile/core/recoverbull/domain/entity/backup_provider_type.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/bull_backup.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file_metadata.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_all_drive_backups_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_drive_backup_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_status_usecase.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/errors.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RecoverBullSelectVaultCubit extends Cubit<RecoverBullSelectVaultState> {
  final FetchAllDriveBackupsUsecase _fetchAllDriveBackupsUsecase;
  final FetchDriveBackupUsecase _fetchDriveBackupUsecase;
  // ignore: unused_field //TODO remove
  final TheDirtyUsecase _checkWalletStatusUsecase;

  RecoverBullSelectVaultCubit({
    required FetchAllDriveBackupsUsecase fetchAllDriveBackupsUsecase,
    required FetchDriveBackupUsecase fetchDriveBackupUsecase,
    required TheDirtyUsecase checkWalletStatusUsecase,
    required BackupProviderType selectedProvider,
  }) : _fetchAllDriveBackupsUsecase = fetchAllDriveBackupsUsecase,
       _fetchDriveBackupUsecase = fetchDriveBackupUsecase,
       _checkWalletStatusUsecase = checkWalletStatusUsecase,
       super(RecoverBullSelectVaultState(selectedProvider: selectedProvider)) {
    if (selectedProvider == BackupProviderType.googleDrive) {
      fetchDriveBackups();
    }
  }

  Future<void> fetchDriveBackups() async {
    try {
      final backups = await _fetchAllDriveBackupsUsecase.execute();
      emit(state.copyWith(driveMetadata: backups));
    } catch (e) {
      emit(state.copyWith(error: FetchAllDriveBackupsError()));
    }
  }

  Future<void> selectDriveBackup(DriveFileMetadata backupMetadata) async {
    emit(state.copyWith(error: null, selectedBackup: null));
    final backupFile = await _fetchDriveBackupUsecase.execute(backupMetadata);
    final backup = BullBackupEntity(backupFile: backupFile);
    emit(state.copyWith(selectedBackup: backup));
  }

  Future<void> clearSelectedBackup() async {
    emit(state.copyWith(error: null, selectedBackup: null));
  }
}
