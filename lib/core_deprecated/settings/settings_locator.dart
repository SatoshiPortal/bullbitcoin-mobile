import 'package:bb_mobile/core_deprecated/settings/data/settings_datasource.dart';
import 'package:bb_mobile/core_deprecated/settings/data/settings_repository.dart';
import 'package:bb_mobile/core_deprecated/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core_deprecated/settings/domain/repositories/settings_repository.dart'
    as domain;
import 'package:bb_mobile/core_deprecated/settings/domain/update_tor_settings_usecase.dart';
import 'package:bb_mobile/core_deprecated/settings/domain/watch_currency_changes_usecase.dart';
import 'package:bb_mobile/core/infra/database/sqlite_database.dart';
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

    // Register the interface for new code, resolving to the same instance
    locator.registerLazySingleton<domain.SettingsRepository>(
      () => locator<SettingsRepository>(),
    );
  }

  static void registerUsecases(GetIt locator) {
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
