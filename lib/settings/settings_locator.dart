import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/_core/domain/usecases/get_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/get_currency_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/get_environment_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/get_hide_amounts_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/get_language_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/settings/domain/usecases/set_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/settings/domain/usecases/set_currency_usecase.dart';
import 'package:bb_mobile/settings/domain/usecases/set_environment_usecase.dart';
import 'package:bb_mobile/settings/domain/usecases/set_hide_amounts_usecase.dart';
import 'package:bb_mobile/settings/domain/usecases/set_language_usecase.dart';
import 'package:bb_mobile/settings/presentation/bloc/settings_cubit.dart';

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
      () => SetLanguageUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<SetCurrencyUsecase>(
      () => SetCurrencyUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<SetHideAmountsUsecase>(
      () => SetHideAmountsUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    // Bloc
    locator.registerFactory<SettingsCubit>(
      () => SettingsCubit(
        setEnvironmentUsecase: locator<SetEnvironmentUsecase>(),
        getEnvironmentUsecase: locator<GetEnvironmentUsecase>(),
        setBitcoinUnitUsecase: locator<SetBitcoinUnitUsecase>(),
        getBitcoinUnitUsecase: locator<GetBitcoinUnitUsecase>(),
        setLanguageUsecase: locator<SetLanguageUsecase>(),
        getLanguageUsecase: locator<GetLanguageUsecase>(),
        getCurrencyUsecase: locator<GetCurrencyUsecase>(),
        setCurrencyUsecase: locator<SetCurrencyUsecase>(),
        setHideAmountsUsecase: locator<SetHideAmountsUsecase>(),
        getHideAmountsUsecase: locator<GetHideAmountsUsecase>(),
      ),
    );
  }
}
