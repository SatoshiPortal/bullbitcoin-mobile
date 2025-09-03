import 'dart:io';

import 'package:bb_mobile/core/recoverbull/domain/entity/backup_provider_type.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file_metadata.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_all_drive_backups_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_drive_backup_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/select_file_path_usecase.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/errors.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/presentation/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RecoverBullSelectVaultCubit extends Cubit<RecoverBullSelectVaultState> {
  final FetchAllDriveFileMetadataUsecase _fetchAllDriveFileMetadataUsecase;
  final FetchDriveBackupUsecase _fetchDriveBackupUsecase;
  final SelectFileFromPathUsecase _selectFileFromPathUsecase;

  RecoverBullSelectVaultCubit({
    required FetchAllDriveFileMetadataUsecase fetchAllDriveFileMetadataUsecase,
    required FetchDriveBackupUsecase fetchDriveBackupUsecase,
    required SelectFileFromPathUsecase selectFileFromPathUsecase,
  }) : _fetchAllDriveFileMetadataUsecase = fetchAllDriveFileMetadataUsecase,
       _fetchDriveBackupUsecase = fetchDriveBackupUsecase,
       _selectFileFromPathUsecase = selectFileFromPathUsecase,
       super(const RecoverBullSelectVaultState());

  Future<void> selectProvider(BackupProviderType provider) async {
    emit(state.copyWith(selectedProvider: provider));
  }

  Future<void> fetchDriveBackups() async {
    try {
      emit(state.copyWith(isLoading: true));
      final backups = await _fetchAllDriveFileMetadataUsecase.execute();
      emit(state.copyWith(driveMetadata: backups));
    } catch (e) {
      emit(state.copyWith(error: FetchAllDriveFilesError()));
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> selectDriveBackup(DriveFileMetadata backupMetadata) async {
    emit(state.copyWith(error: null, selectedBackup: null));
    final backupFile = await _fetchDriveBackupUsecase.execute(backupMetadata);
    final backup = EncryptedVault(backupFile: backupFile);
    emit(state.copyWith(selectedBackup: backup));
  }

  Future<void> clearSelectedBackup() async {
    emit(state.copyWith(error: null, selectedBackup: null));
  }

  Future<void> clearState() async {
    emit(const RecoverBullSelectVaultState());
  }

  void updateSelectedProvider(BackupProviderType provider) {
    emit(
      state.copyWith(
        selectedProvider: provider,
        error: null,
        selectedBackup: null,
      ),
    );
    if (provider == BackupProviderType.googleDrive) {
      fetchDriveBackups();
    }
  }

  Future<void> selectCustomLocationBackup() async {
    try {
      final selectedFile = await _selectFileFromPathUsecase.execute();
      if (selectedFile == null) {
        emit(state.copyWith(error: FileNotSelectedError()));
      }

      final backupFile = await File(selectedFile!).readAsString();

      if (!EncryptedVault.isValid(backupFile)) {
        emit(state.copyWith(error: RecoverbullBackupFileNotValidError()));
      }

      final backup = EncryptedVault(backupFile: backupFile);
      emit(state.copyWith(selectedBackup: backup));
    } catch (e) {
      emit(state.copyWith(error: SelectFileFromPathError()));
    }
  }
}
