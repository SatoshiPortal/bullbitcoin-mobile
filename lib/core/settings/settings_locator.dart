import 'package:bb_mobile/core/settings/data/repository/settings_repository_impl.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/usecases/get_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/core/settings/domain/usecases/get_currency_usecase.dart';
import 'package:bb_mobile/core/settings/domain/usecases/get_environment_usecase.dart';
import 'package:bb_mobile/core/settings/domain/usecases/get_hide_amounts_usecase.dart';
import 'package:bb_mobile/core/settings/domain/usecases/get_language_usecase.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/impl/hive_storage_datasource_impl.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/locator.dart';
import 'package:hive/hive.dart';

class SettingsLocator {
  static Future<void> registerRepositories() async {
    final settingsBox =
        await Hive.openBox<String>(HiveBoxNameConstants.settings);
    locator.registerLazySingleton<SettingsRepository>(
      () => SettingsRepositoryImpl(
        storage: HiveStorageDatasourceImpl<String>(settingsBox),
      ),
    );
  }

  static void registerUsecases() {
    locator.registerFactory<GetBitcoinUnitUsecase>(
      () => GetBitcoinUnitUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<GetCurrencyUsecase>(
      () => GetCurrencyUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<GetEnvironmentUsecase>(
      () => GetEnvironmentUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<GetHideAmountsUsecase>(
      () => GetHideAmountsUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<GetLanguageUsecase>(
      () => GetLanguageUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
  }
}
