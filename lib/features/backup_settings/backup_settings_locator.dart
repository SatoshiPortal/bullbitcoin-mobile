import 'package:bb_mobile/core/recoverbull/domain/usecases/create_vault_key_from_default_seed_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/pick_file_content_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/save_file_to_system_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:bb_mobile/locator.dart';

class BackupSettingsLocator {
  static void setup() {
    // Blocs
    locator.registerFactory<BackupSettingsCubit>(
      () => BackupSettingsCubit(
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        settingsRepository: locator<SettingsRepository>(),
        saveFileToSystemUsecase: locator<SaveFileToSystemUsecase>(),
        createBackupKeyFromDefaultSeedUsecase:
            locator<CreateVaultKeyFromDefaultSeedUsecase>(),
        selectFileFromPathUsecase: locator<PickFileContentUsecase>(),
        fetchLatestGoogleDriveBackupUsecase:
            locator<FetchLatestGoogleDriveVaultUsecase>(),
        connectToGoogleDriveUsecase: locator<ConnectToGoogleDriveUsecase>(),
      ),
    );
  }
}
