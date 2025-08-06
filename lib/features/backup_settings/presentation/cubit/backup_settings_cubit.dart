import 'package:bb_mobile/core/recoverbull/domain/entity/backup_info.dart';
import 'package:bb_mobile/core/recoverbull/domain/errors/recover_wallet_error.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/create_backup_key_from_default_seed_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_backup_from_file_system_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/save_to_file_system_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/select_file_path_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/select_folder_path_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
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
      final isDefaultPhysicalBackupTested = defaultWallets.every(
        (e) => e.isPhysicalBackupTested,
      );
      final isDefaultEncryptedBackupTested = defaultWallets.every(
        (e) => e.isEncryptedVaultTested,
      );
      final lastPhysicalBackup =
          defaultWallets
              .firstWhere((e) => e.network == Network.bitcoinMainnet)
              .latestPhysicalBackup;
      final lastEncryptedBackup =
          defaultWallets
              .firstWhere((e) => e.network == Network.bitcoinMainnet)
              .latestEncryptedBackup;
      emit(
        state.copyWith(
          isDefaultPhysicalBackupTested: isDefaultPhysicalBackupTested,
          isDefaultEncryptedBackupTested: isDefaultEncryptedBackupTested,
          lastPhysicalBackup: lastPhysicalBackup,
          lastEncryptedBackup: lastEncryptedBackup,
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
      await _connectToGoogleDriveUsecase.execute();
      final (content: content, fileName: _) =
          await _fetchLatestGoogleDriveBackupUsecase.execute();
      final folderPath = await _selectFolderPathUsecase.execute();
      if (folderPath == null) {
        emit(state.copyWith(status: BackupSettingsStatus.initial));
        return;
      }

      await _saveToFileSystemUsecase.execute(folderPath, content);
      emit(
        state.copyWith(
          status: BackupSettingsStatus.success,
          downloadedBackupFile: content,
        ),
      );
    } catch (e) {
      log.severe('exportVault error: $e');
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

      final backupInfo = backupFile.backupInfo;
      if (backupInfo.isCorrupted) {
        emit(
          state.copyWith(
            status: BackupSettingsStatus.error,
            error: const BackupVaultCorruptedError(),
          ),
        );
        return;
      }

      final path = backupInfo.path;
      if (path == null) {
        emit(
          state.copyWith(
            status: BackupSettingsStatus.error,
            error: const BackupVaultMissingDerivationPathError(),
          ),
        );
        return;
      }

      String? backupKey;
      try {
        backupKey = await _createBackupKeyFromDefaultSeedUsecase.execute(path);
      } catch (e) {
        log.severe('Local backup key derivation failed: $e');
        emit(
          state.copyWith(
            status: BackupSettingsStatus.error,
            error: const BackupKeyDerivationFailedError(),
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
      log.severe('viewVaultKey error: $e');
      emit(
        state.copyWith(status: BackupSettingsStatus.error, error: e.toString()),
      );
    }
  }

  void clearDownloadedData() {
    emit(
      state.copyWith(
        downloadedBackupFile: null,
        selectedBackupFile: null,
        status: BackupSettingsStatus.initial,
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

  Future<void> selectGoogleDriveProvider() async {
    try {
      emit(state.copyWith(status: BackupSettingsStatus.loading, error: null));

      await _connectToGoogleDriveUsecase.execute();

      // Fetch the latest backup file from Google Drive
      final (content: content, fileName: fileName) =
          await _fetchLatestGoogleDriveBackupUsecase.execute();

      emit(
        state.copyWith(
          status: BackupSettingsStatus.success,
          selectedBackupFile: content,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: BackupSettingsStatus.error, error: e.toString()),
      );
    }
  }

  Future<void> selectFileSystemProvider() async {
    try {
      emit(state.copyWith(status: BackupSettingsStatus.loading, error: null));

      // Select backup file from file system
      final filePath = await _selectFileFromPathUsecase.execute();
      if (filePath == null) {
        emit(state.copyWith(status: BackupSettingsStatus.initial));
        return;
      }

      // Read the backup file content
      final content = await _fetchBackupFromFileSystemUsecase.execute(filePath);

      emit(
        state.copyWith(
          status: BackupSettingsStatus.success,
          selectedBackupFile: content,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: BackupSettingsStatus.error, error: e.toString()),
      );
    }
  }
}
