import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/get_old_seeds_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_currency_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_environment_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_hide_amounts_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_is_superuser_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_language_usecase.dart';

import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/locator.dart';

class SettingsLocator {
  static void setup() {
    // Usecases
    locator.registerFactory<SetEnvironmentUsecase>(
      () => SetEnvironmentUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<SetBitcoinUnitUsecase>(
      () => SetBitcoinUnitUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<SetLanguageUsecase>(
      () =>
          SetLanguageUsecase(settingsRepository: locator<SettingsRepository>()),
    );
    locator.registerFactory<SetCurrencyUsecase>(
      () =>
          SetCurrencyUsecase(settingsRepository: locator<SettingsRepository>()),
    );
    locator.registerFactory<SetHideAmountsUsecase>(
      () => SetHideAmountsUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<SetIsSuperuserUsecase>(
      () => SetIsSuperuserUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    // Blocs
    locator.registerFactory<SettingsCubit>(
      () => SettingsCubit(
        setEnvironmentUsecase: locator<SetEnvironmentUsecase>(),
        getSettingsUsecase: locator<GetSettingsUsecase>(),
        setBitcoinUnitUsecase: locator<SetBitcoinUnitUsecase>(),
        setLanguageUsecase: locator<SetLanguageUsecase>(),
        setCurrencyUsecase: locator<SetCurrencyUsecase>(),
        setHideAmountsUsecase: locator<SetHideAmountsUsecase>(),
        setIsSuperuserUsecase: locator<SetIsSuperuserUsecase>(),
        getOldSeedsUsecase: locator<GetOldSeedsUsecase>(),
      ),
    );
  }
}
