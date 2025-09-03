import 'package:bb_mobile/core/recoverbull/domain/usecases/create_vault_key_from_default_seed_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_encrypted_vault_from_file_system_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/save_to_file_system_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/select_file_path_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/select_folder_path_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:bb_mobile/locator.dart';

class BackupSettingsLocator {
  static void setup() {
    // Blocs
    locator.registerFactory<BackupSettingsCubit>(
      () => BackupSettingsCubit(
        getWalletsUsecase: locator<GetWalletsUsecase>(),

        selectFolderPathUsecase: locator<SelectFolderPathUsecase>(),
        saveToFileSystemUsecase: locator<SaveToFileSystemUsecase>(),
        createBackupKeyFromDefaultSeedUsecase:
            locator<CreateVaultKeyFromDefaultSeedUsecase>(),
        selectFileFromPathUsecase: locator<SelectFileFromPathUsecase>(),
        fetchEncryptedVaultFromFileSystemUsecase:
            locator<FetchEncryptedVaultFromFileSystemUsecase>(),
        fetchLatestGoogleDriveBackupUsecase:
            locator<FetchLatestGoogleDriveVaultUsecase>(),
        connectToGoogleDriveUsecase: locator<ConnectToGoogleDriveUsecase>(),
      ),
    );
  }
}
