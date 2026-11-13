import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/backup_settings/domain/read_backup_status_usecase.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:get_it/get_it.dart';

class BackupSettingsLocator {
  static void setup(GetIt locator) {
    // Blocs
    locator.registerFactory<BackupSettingsCubit>(
      () => BackupSettingsCubit(
        ReadBackupStatusUsecase(
          locator<GetWalletsUsecase>(),
          locator<SettingsRepository>(),
          locator<RecoverBullFacade>().status,
        ),
      ),
    );
  }
}
