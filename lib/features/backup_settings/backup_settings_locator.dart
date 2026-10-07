import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/get_encrypted_backup_status_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';

class BackupSettingsLocator {
  static void setup(GetIt locator) {
    // Use cases
    locator.registerFactory<GetEncryptedBackupStatusUsecase>(
      () => GetEncryptedBackupStatusUsecase(
        recoverBullStatus: locator<RecoverBullFeature>().status,
      ),
    );

    // Blocs
    locator.registerFactory<BackupSettingsCubit>(
      () => BackupSettingsCubit(
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        getSettingsUsecase: locator<GetSettingsUsecase>(),
        getEncryptedBackupStatusUsecase:
            locator<GetEncryptedBackupStatusUsecase>(),
      ),
    );
  }
}
