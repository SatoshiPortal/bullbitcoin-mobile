import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file_metadata.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/vault_provider.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_all_drive_file_metadata_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_vault_from_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/pick_file_content_usecase.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/errors.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/presentation/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RecoverBullSelectVaultCubit extends Cubit<RecoverBullSelectVaultState> {
  final FetchAllDriveFileMetadataUsecase _fetchAllDriveFileMetadataUsecase;
  final FetchVaultFromDriveUsecase _fetchDriveBackupUsecase;
  final PickFileContentUsecase _selectFileFromPathUsecase;

  RecoverBullSelectVaultCubit({
    required FetchAllDriveFileMetadataUsecase fetchAllDriveFileMetadataUsecase,
    required FetchVaultFromDriveUsecase fetchDriveBackupUsecase,
    required PickFileContentUsecase selectFileFromPathUsecase,
  }) : _fetchAllDriveFileMetadataUsecase = fetchAllDriveFileMetadataUsecase,
       _fetchDriveBackupUsecase = fetchDriveBackupUsecase,
       _selectFileFromPathUsecase = selectFileFromPathUsecase,
       super(const RecoverBullSelectVaultState());

  Future<void> selectProvider(VaultProvider provider) async {
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
    try {
      emit(
        state.copyWith(
          error: null,
          selectedVault: null,
          isSelectingVault: true,
        ),
      );
      final vaultFile = await _fetchDriveBackupUsecase.execute(backupMetadata);
      final vault = EncryptedVault(file: vaultFile);
      emit(state.copyWith(selectedVault: vault, isSelectingVault: false));
    } catch (e) {
      emit(
        state.copyWith(
          error: FetchAllDriveFilesError(),
          isSelectingVault: false,
        ),
      );
    }
  }

  Future<void> clearSelectedBackup() async {
    emit(state.copyWith(error: null, selectedVault: null));
  }

  Future<void> clearState() async {
    emit(const RecoverBullSelectVaultState());
  }

  void updateSelectedProvider(VaultProvider provider) {
    emit(
      state.copyWith(
        selectedProvider: provider,
        error: null,
        selectedVault: null,
      ),
    );
    if (provider == VaultProvider.googleDrive) {
      fetchDriveBackups();
    }
  }

  Future<void> selectCustomLocationBackup() async {
    try {
      final fileContent = await _selectFileFromPathUsecase.execute();

      if (!EncryptedVault.isValid(fileContent)) {
        emit(state.copyWith(error: RecoverbullBackupFileNotValidError()));
      }
      final vault = EncryptedVault(file: fileContent);
      emit(state.copyWith(selectedVault: vault));
    } catch (e) {
      emit(state.copyWith(error: SelectFileFromPathError()));
    }
  }
}
