import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_currency_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_environment_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_hide_amounts_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_is_dev_mode_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_is_superuser_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_language_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_theme_mode_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';

class SettingsDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {}

  @override
  Future<void> registerDrivenAdapters() async {}

  @override
  Future<void> registerApplicationServices() async {}

  @override
  Future<void> registerUseCases() async {
    sl.registerFactory<SetEnvironmentUsecase>(
      () => SetEnvironmentUsecase(
        settingsRepository: sl(),
      ),
    );
    sl.registerFactory<SetBitcoinUnitUsecase>(
      () => SetBitcoinUnitUsecase(
        settingsRepository: sl(),
      ),
    );
    sl.registerFactory<SetLanguageUsecase>(
      () => SetLanguageUsecase(settingsRepository: sl()),
    );
    sl.registerFactory<SetCurrencyUsecase>(
      () => SetCurrencyUsecase(settingsRepository: sl()),
    );
    sl.registerFactory<SetHideAmountsUsecase>(
      () => SetHideAmountsUsecase(
        settingsRepository: sl(),
      ),
    );
    sl.registerFactory<SetIsSuperuserUsecase>(
      () => SetIsSuperuserUsecase(
        settingsRepository: sl(),
      ),
    );

    sl.registerFactory<SetIsDevModeUsecase>(
      () => SetIsDevModeUsecase(
        settingsRepository: sl(),
      ),
    );

    sl.registerFactory<SetThemeModeUsecase>(
      () => SetThemeModeUsecase(
        settingsRepository: sl(),
      ),
    );
  }

  @override
  Future<void> registerDrivingAdapters() async {
    sl.registerFactory<SettingsCubit>(
      () => SettingsCubit(
        setEnvironmentUsecase: sl(),
        getSettingsUsecase: sl(),
        setBitcoinUnitUsecase: sl(),
        setLanguageUsecase: sl(),
        setCurrencyUsecase: sl(),
        setHideAmountsUsecase: sl(),
        setIsSuperuserUsecase: sl(),
        getOldSeedsUsecase: sl(),
        setIsDevModeUsecase: sl(),
        setThemeModeUsecase: sl(),
        revokeArkUsecase: sl(),
      ),
    );
  }
}
