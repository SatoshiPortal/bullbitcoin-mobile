import 'package:bb_mobile/core/settings/data/settings_datasource.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart'
    as domain;
import 'package:bb_mobile/core/settings/domain/update_tor_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/watch_currency_changes_usecase.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/locator.dart';

class SettingsLocator {
  static Future<void> registerDatasources() async {
    locator.registerLazySingleton<SettingsDatasource>(
      () => SettingsDatasource(sqlite: locator<SqliteDatabase>()),
    );
  }

  static Future<void> registerRepositories() async {
    // Register the concrete class for legacy code
    locator.registerLazySingleton<SettingsRepository>(
      () => SettingsRepository(
        settingsDatasource: locator<SettingsDatasource>(),
      ),
    );

    // Register the interface for new code, resolving to the same instance
    locator.registerLazySingleton<domain.SettingsRepository>(
      () => locator<SettingsRepository>(),
    );
  }

  static void registerUsecases() {
    locator.registerFactory<GetSettingsUsecase>(
      () =>
          GetSettingsUsecase(settingsRepository: locator<SettingsRepository>()),
    );
    locator.registerFactory<UpdateTorSettingsUsecase>(
      () => UpdateTorSettingsUsecase(
        settingsRepository: locator<domain.SettingsRepository>(),
      ),
    );
    locator.registerFactory<WatchCurrencyChangesUsecase>(
      () => WatchCurrencyChangesUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
  }
}
