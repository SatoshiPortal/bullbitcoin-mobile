import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';

class BackupSettingsLocator {
  static void setup(GetIt locator) {
    // Blocs
    locator.registerFactory<BackupSettingsCubit>(
      () => BackupSettingsCubit(
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        settingsRepository: locator<SettingsRepository>(),
        recoverBullStatus: locator<RecoverBullFeature>().status,
      ),
    );
  }
}
