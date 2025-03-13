import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/_core/domain/usecases/get_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/get_currency_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/get_environment_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/get_language_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/settings/domain/usecases/set_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/settings/domain/usecases/set_currency_usecase.dart';
import 'package:bb_mobile/settings/domain/usecases/set_language_usecase.dart';
import 'package:bb_mobile/settings/domain/usecases/set_environment_usecase.dart';
import 'package:bb_mobile/settings/presentation/bloc/settings_cubit.dart';

class SettingsLocator {
  static void setup() {
    // Usecases
    locator.registerFactory<SetEnvironmentUseCase>(
      () => SetEnvironmentUseCase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<SetBitcoinUnitUseCase>(
      () => SetBitcoinUnitUseCase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<SetLanguageUseCase>(
      () => SetLanguageUseCase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<SetCurrencyUseCase>(
      () => SetCurrencyUseCase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    // Bloc
    locator.registerFactory<SettingsCubit>(
      () => SettingsCubit(
        setEnvironmentUseCase: locator<SetEnvironmentUseCase>(),
        getEnvironmentUseCase: locator<GetEnvironmentUseCase>(),
        setBitcoinUnitUseCase: locator<SetBitcoinUnitUseCase>(),
        getBitcoinUnitUseCase: locator<GetBitcoinUnitUseCase>(),
        setLanguageUseCase: locator<SetLanguageUseCase>(),
        getLanguageUseCase: locator<GetLanguageUseCase>(),
        getCurrencyUseCase: locator<GetCurrencyUseCase>(),
        setCurrencyUseCase: locator<SetCurrencyUseCase>(),
      ),
    );
  }
}
