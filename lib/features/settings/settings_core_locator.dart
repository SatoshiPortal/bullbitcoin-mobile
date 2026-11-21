import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:get_it/get_it.dart';
import 'package:preferences/preferences.dart' as domain;

class SettingsLocator {
  static Future<void> registerRepositories(GetIt locator) async {
    locator.registerLazySingleton<domain.Preferences>(
      () => domain.Preferences.open(database: locator<SqliteDatabase>()),
    );

    locator.registerLazySingleton<domain.AmountDisplayPreferencesReader>(
      () => locator<domain.Preferences>(),
    );
    locator.registerLazySingleton<domain.ActiveEnvironmentReader>(
      () => locator<domain.Preferences>(),
    );
    locator.registerLazySingleton<domain.ConnectionPreferencesReader>(
      () => locator<domain.Preferences>(),
    );
    locator.registerLazySingleton<domain.DeveloperEnvironmentReader>(
      () => locator<domain.Preferences>(),
    );
    locator.registerLazySingleton<domain.RuntimeDisplayPreferencesReader>(
      () => locator<domain.Preferences>(),
    );
    locator.registerLazySingleton<domain.AmountInputPreferences>(
      () => locator<domain.Preferences>(),
    );
    locator.registerLazySingleton<domain.TorProxyPreferencesReader>(
      () => locator<domain.Preferences>(),
    );
    locator.registerLazySingleton<domain.ExchangeTestnetBasicAuthPreferences>(
      () => locator<domain.Preferences>(),
    );
    locator.registerLazySingleton<domain.AnnouncementDismissals>(
      () => locator<domain.Preferences>().announcementDismissals,
    );
    locator.registerLazySingleton<domain.RecoverBullPreferences>(
      () => locator<domain.Preferences>().recoverBull,
    );
  }
}
