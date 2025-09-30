import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/errors/recover_wallet_error.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/create_vault_key_from_default_seed_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/pick_file_content_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/save_to_file_system_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/select_folder_path_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
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
    required SettingsRepository settingsRepository,
    required SelectFolderPathUsecase selectFolderPathUsecase,
    required SaveToFileSystemUsecase saveToFileSystemUsecase,
    required CreateVaultKeyFromDefaultSeedUsecase
    createBackupKeyFromDefaultSeedUsecase,
    required PickFileContentUsecase selectFileFromPathUsecase,
    required FetchLatestGoogleDriveVaultUsecase
    fetchLatestGoogleDriveBackupUsecase,
    required ConnectToGoogleDriveUsecase connectToGoogleDriveUsecase,
  }) : _getWalletsUsecase = getWalletsUsecase,
       _selectFolderPathUsecase = selectFolderPathUsecase,
       _saveToFileSystemUsecase = saveToFileSystemUsecase,
       _createBackupKeyFromDefaultSeedUsecase =
           createBackupKeyFromDefaultSeedUsecase,
       _selectFileFromPathUsecase = selectFileFromPathUsecase,
       _fetchLatestGoogleDriveBackupUsecase =
           fetchLatestGoogleDriveBackupUsecase,
       _connectToGoogleDriveUsecase = connectToGoogleDriveUsecase,
       _settingsRepository = settingsRepository,

       super(BackupSettingsState());

  final GetWalletsUsecase _getWalletsUsecase;
  final SelectFolderPathUsecase _selectFolderPathUsecase;
  final SaveToFileSystemUsecase _saveToFileSystemUsecase;
  final CreateVaultKeyFromDefaultSeedUsecase
  _createBackupKeyFromDefaultSeedUsecase;
  final SettingsRepository _settingsRepository;
  final PickFileContentUsecase _selectFileFromPathUsecase;
  final FetchLatestGoogleDriveVaultUsecase _fetchLatestGoogleDriveBackupUsecase;
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

      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;
      final network = Network.fromEnvironment(
        isTestnet: environment.isTestnet,
        isLiquid: false,
      );

      final lastPhysicalBackup =
          defaultWallets
              .firstWhere((e) => e.network == network)
              .latestPhysicalBackup;
      final lastEncryptedBackup =
          defaultWallets
              .firstWhere((e) => e.network == network)
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

      await _saveToFileSystemUsecase.execute(content);
      emit(
        state.copyWith(
          status: BackupSettingsStatus.success,
          downloadedBackupFile: content,
        ),
      );
    } catch (e) {
      log.severe('exportVault: $e');
      emit(
        state.copyWith(status: BackupSettingsStatus.error, error: e.toString()),
      );
    }
  }

  Future<void> viewVaultKey(EncryptedVault vault) async {
    try {
      emit(
        state.copyWith(status: BackupSettingsStatus.viewingKey, error: null),
      );

      String? vaultKey;
      try {
        vaultKey = await _createBackupKeyFromDefaultSeedUsecase.execute(
          vault.derivationPath,
        );
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
          derivedBackupKey: vaultKey,
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
      final fileContent = await _selectFileFromPathUsecase.execute();
      if (fileContent.isEmpty || !EncryptedVault.isValid(fileContent)) {
        emit(
          state.copyWith(
            status: BackupSettingsStatus.error,
            error: 'Invalid backupfile',
          ),
        );
        return;
      }

      final content = EncryptedVault(file: fileContent).toFile();

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
