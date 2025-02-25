import 'package:bb_mobile/core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/domain/usecases/get_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/get_environment_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/get_language_usecase.dart';
import 'package:bb_mobile/features/app_startup/app_locator.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_language_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_testnet_mode_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';

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

    // Bloc
    locator.registerFactory<SettingsCubit>(
      () => SettingsCubit(
        setEnvironmentUseCase: locator<SetEnvironmentUseCase>(),
        getEnvironmentUseCase: locator<GetEnvironmentUseCase>(),
        setBitcoinUnitUseCase: locator<SetBitcoinUnitUseCase>(),
        getBitcoinUnitUseCase: locator<GetBitcoinUnitUseCase>(),
        setLanguageUseCase: locator<SetLanguageUseCase>(),
        getLanguageUseCase: locator<GetLanguageUseCase>(),
      ),
    );
  }
}
