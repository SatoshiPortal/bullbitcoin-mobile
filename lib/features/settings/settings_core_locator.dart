import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:get_it/get_it.dart';
import 'package:preferences/preferences.dart' as domain;
import 'package:preferences/storage.dart';

class SettingsLocator {
  static Future<void> registerDatasources(GetIt locator) async {
    locator.registerLazySingleton<PreferencesDao>(
      () => locator<SqliteDatabase>().preferencesDao,
    );
  }

  static Future<void> registerRepositories(GetIt locator) async {
    locator.registerLazySingleton<domain.SettingsRepository>(
      () =>
          SettingsRepositoryImpl(settingsDatasource: locator<PreferencesDao>()),
    );

    locator.registerLazySingleton<domain.AmountDisplayPreferencesReader>(
      () => locator<domain.SettingsRepository>(),
    );
    locator.registerLazySingleton<domain.ActiveEnvironmentReader>(
      () => locator<domain.SettingsRepository>(),
    );
    locator.registerLazySingleton<domain.ConnectionPreferencesReader>(
      () => locator<domain.SettingsRepository>(),
    );
    locator.registerLazySingleton<domain.DeveloperEnvironmentReader>(
      () => locator<domain.SettingsRepository>(),
    );
    locator.registerLazySingleton<domain.RuntimeDisplayPreferencesReader>(
      () => locator<domain.SettingsRepository>(),
    );
    locator.registerLazySingleton<domain.AmountInputPreferences>(
      () => locator<domain.SettingsRepository>(),
    );
    locator.registerLazySingleton<domain.TorProxyPreferencesReader>(
      () => locator<domain.SettingsRepository>(),
    );
    locator.registerLazySingleton<domain.ExchangeTestnetBasicAuthPreferences>(
      () => locator<domain.SettingsRepository>(),
    );
    locator.registerLazySingleton<domain.AnnouncementDismissals>(
      () => domain.AnnouncementDismissals(locator<PreferencesDao>()),
    );
    locator.registerLazySingleton<domain.RecoverBullPreferences>(
      () => domain.RecoverBullPreferences(locator<PreferencesDao>()),
    );
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<domain.GetSettingsUsecase>(
      () => domain.GetSettingsUsecase(
        settingsRepository: locator<domain.SettingsRepository>(),
      ),
    );
  }
}
