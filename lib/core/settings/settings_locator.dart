import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/storage/sqlite_datasource.dart';
import 'package:bb_mobile/locator.dart';

class SettingsLocator {
  static Future<void> registerRepositories() async {
    locator.registerLazySingleton<SettingsRepository>(
      () => SettingsRepository(sqliteDatasource: locator<SqliteDatasource>()),
    );
  }

  static void registerUsecases() {
    locator.registerFactory<GetSettingsUsecase>(
      () =>
          GetSettingsUsecase(settingsRepository: locator<SettingsRepository>()),
    );
  }
}
