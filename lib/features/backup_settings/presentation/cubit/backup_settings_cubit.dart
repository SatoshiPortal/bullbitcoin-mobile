import 'package:bb_mobile/core/recoverbull/domain/entity/backup_info.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/create_backup_key_from_default_seed_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_backup_from_file_system_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/save_to_file_system_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/select_file_path_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/select_folder_path_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup_settings_cubit.freezed.dart';
part 'backup_settings_state.dart';

class BackupSettingsCubit extends Cubit<BackupSettingsState> {
  BackupSettingsCubit({
    required GetWalletsUsecase getWalletsUsecase,

    required SelectFolderPathUsecase selectFolderPathUsecase,
    required SaveToFileSystemUsecase saveToFileSystemUsecase,
    required CreateBackupKeyFromDefaultSeedUsecase
    createBackupKeyFromDefaultSeedUsecase,
    required SelectFileFromPathUsecase selectFileFromPathUsecase,
    required FetchBackupFromFileSystemUsecase fetchBackupFromFileSystemUsecase,
    required FetchLatestGoogleDriveBackupUsecase
    fetchLatestGoogleDriveBackupUsecase,
    required ConnectToGoogleDriveUsecase connectToGoogleDriveUsecase,
    required ConnectToGoogleDriveSilentlyUsecase
    connectToGoogleDriveSilentlyUsecase,
  }) : _getWalletsUsecase = getWalletsUsecase,
       _selectFolderPathUsecase = selectFolderPathUsecase,
       _saveToFileSystemUsecase = saveToFileSystemUsecase,
       _createBackupKeyFromDefaultSeedUsecase =
           createBackupKeyFromDefaultSeedUsecase,
       _selectFileFromPathUsecase = selectFileFromPathUsecase,
       _fetchBackupFromFileSystemUsecase = fetchBackupFromFileSystemUsecase,
       _fetchLatestGoogleDriveBackupUsecase =
           fetchLatestGoogleDriveBackupUsecase,
       _connectToGoogleDriveUsecase = connectToGoogleDriveUsecase,
       _connectToGoogleDriveSilentlyUsecase =
           connectToGoogleDriveSilentlyUsecase,
       super(BackupSettingsState());

  final GetWalletsUsecase _getWalletsUsecase;
  final SelectFolderPathUsecase _selectFolderPathUsecase;
  final SaveToFileSystemUsecase _saveToFileSystemUsecase;
  final CreateBackupKeyFromDefaultSeedUsecase
  _createBackupKeyFromDefaultSeedUsecase;
  final SelectFileFromPathUsecase _selectFileFromPathUsecase;
  final FetchBackupFromFileSystemUsecase _fetchBackupFromFileSystemUsecase;
  final FetchLatestGoogleDriveBackupUsecase
  _fetchLatestGoogleDriveBackupUsecase;
  final ConnectToGoogleDriveUsecase _connectToGoogleDriveUsecase;
  final ConnectToGoogleDriveSilentlyUsecase
  _connectToGoogleDriveSilentlyUsecase;

  Future<void> checkBackupStatus() async {
    try {
      emit(state.copyWith(status: BackupSettingsStatus.loading));

      final defaultWallets = await _getWalletsUsecase.execute(
        onlyDefaults: true,
      );
      if (defaultWallets.isEmpty) {
        emit(state.copyWith(status: BackupSettingsStatus.success));
        return;
      }

      emit(
        state.copyWith(
          isDefaultPhysicalBackupTested: defaultWallets.every(
            (e) => e.isPhysicalBackupTested,
          ),
          isDefaultEncryptedBackupTested: defaultWallets.every(
            (e) => e.isEncryptedVaultTested,
          ),
          lastPhysicalBackup:
              defaultWallets
                  .firstWhere((e) => e.network == Network.bitcoinMainnet)
                  .latestPhysicalBackup,
          lastEncryptedBackup:
              defaultWallets
                  .firstWhere((e) => e.network == Network.bitcoinMainnet)
                  .latestEncryptedBackup,
          status: BackupSettingsStatus.success,
          error: null,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: BackupSettingsStatus.error, error: e));
    }
  }

  Future<void> exportVault() async {
    try {
      emit(state.copyWith(status: BackupSettingsStatus.exporting, error: null));
      try {
        await _connectToGoogleDriveSilentlyUsecase.execute();
      } catch (_) {
        await _connectToGoogleDriveUsecase.execute();
      }
      final (content, fileName) =
          await _fetchLatestGoogleDriveBackupUsecase.execute();
      final folderPath = await _selectFolderPathUsecase.execute();
      if (folderPath == null) {
        emit(state.copyWith(status: BackupSettingsStatus.initial));
        return;
      }
      final filePath = '$folderPath/$fileName';
      await _saveToFileSystemUsecase.execute(filePath, content);
      emit(
        state.copyWith(
          status: BackupSettingsStatus.success,
          downloadedBackupFile: content,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: BackupSettingsStatus.error, error: e.toString()),
      );
    }
  }

  Future<void> viewVaultKey(String backupFile) async {
    try {
      emit(
        state.copyWith(status: BackupSettingsStatus.viewingKey, error: null),
      );

      final backupInfo = BackupInfo(backupFile: backupFile);
      if (backupInfo.isCorrupted) {
        emit(
          state.copyWith(
            status: BackupSettingsStatus.error,
            error: 'Selected backup file is corrupted',
          ),
        );
        return;
      }

      final path = backupInfo.path;
      if (path == null) {
        emit(
          state.copyWith(
            status: BackupSettingsStatus.error,
            error: 'Backup file missing derivation path',
          ),
        );
        return;
      }

      String? backupKey;
      try {
        backupKey = await _createBackupKeyFromDefaultSeedUsecase.execute(path);
      } catch (e) {
        emit(
          state.copyWith(
            downloadedBackupFile: backupFile,
            status: BackupSettingsStatus.error,
            error: 'Local backup key derivation failed.',
          ),
        );

        return;
      }

      emit(
        state.copyWith(
          status: BackupSettingsStatus.success,
          derivedBackupKey: backupKey,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: BackupSettingsStatus.error, error: e.toString()),
      );
    }
  }

  void clearDownloadedData() {
    emit(
      state.copyWith(
        downloadedBackupFile: null,
        derivedBackupKey: null,
        error: null,
      ),
    );
  }

  Future<String?> selectBackupFile() async {
    return await _selectFileFromPathUsecase.execute();
  }

  Future<String> readBackupFile(String filePath) async {
    return await _fetchBackupFromFileSystemUsecase.execute(filePath);
  }
}
