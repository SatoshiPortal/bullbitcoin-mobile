import 'dart:io';

import 'package:bb_mobile/core/recoverbull/domain/entity/backup_provider_type.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file_metadata.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_all_drive_file_metadata_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_vault_from_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/select_file_path_usecase.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/errors.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/presentation/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RecoverBullSelectVaultCubit extends Cubit<RecoverBullSelectVaultState> {
  final FetchAllDriveFileMetadataUsecase _fetchAllDriveFileMetadataUsecase;
  final FetchVaultFromDriveUsecase _fetchDriveBackupUsecase;
  final SelectFileFromPathUsecase _selectFileFromPathUsecase;

  RecoverBullSelectVaultCubit({
    required FetchAllDriveFileMetadataUsecase fetchAllDriveFileMetadataUsecase,
    required FetchVaultFromDriveUsecase fetchDriveBackupUsecase,
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
    final vaultFile = await _fetchDriveBackupUsecase.execute(backupMetadata);
    final vault = EncryptedVault(file: vaultFile);
    emit(state.copyWith(selectedBackup: vault));
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

      final fileSelectedContent = await File(selectedFile!).readAsString();

      if (!EncryptedVault.isValid(fileSelectedContent)) {
        emit(state.copyWith(error: RecoverbullBackupFileNotValidError()));
      }

      final backup = EncryptedVault(file: fileSelectedContent);
      emit(state.copyWith(selectedBackup: backup));
    } catch (e) {
      emit(state.copyWith(error: SelectFileFromPathError()));
    }
  }
}
