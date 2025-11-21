import 'package:bb_mobile/core/settings/data/settings_datasource.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/watch_currency_changes_usecase.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:get_it/get_it.dart';

class SettingsLocator {
  static Future<void> registerDatasources(GetIt locator) async {
    locator.registerLazySingleton<SettingsDatasource>(
      () => SettingsDatasource(sqlite: locator<SqliteDatabase>()),
    );
  }

  static Future<void> registerRepositories(GetIt locator) async {
    locator.registerLazySingleton<SettingsRepository>(
      () =>
          SettingsRepository(settingsDatasource: locator<SettingsDatasource>()),
    );
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<GetSettingsUsecase>(
      () =>
          GetSettingsUsecase(settingsRepository: locator<SettingsRepository>()),
    );
    locator.registerFactory<WatchCurrencyChangesUsecase>(
      () => WatchCurrencyChangesUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
  }
}
