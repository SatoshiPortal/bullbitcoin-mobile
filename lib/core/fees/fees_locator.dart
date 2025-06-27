import 'package:bb_mobile/core/fees/data/fees_datasource.dart';
import 'package:bb_mobile/core/fees/data/fees_repository.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/locator.dart';

class FeesLocator {
  static void registerDatasources() {
    locator.registerLazySingleton<FeesDatasource>(() => FeesDatasource());
  }

  static void registerRepositories() {
    locator.registerLazySingleton<FeesRepository>(
      () => FeesRepository(feesDatasource: locator<FeesDatasource>()),
    );
  }

  static void registerUseCases() {
    locator.registerFactory<GetNetworkFeesUsecase>(
      () => GetNetworkFeesUsecase(
        feesRepository: locator<FeesRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
  }
}
