import 'package:bb_mobile/core/fees/data/fees_datasource.dart';
import 'package:bb_mobile/core/fees/data/fees_repository.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/mempool/application/usecases/get_active_mempool_server_usecase.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_settings_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:get_it/get_it.dart';

class FeesLocator {
  static void registerDatasources(GetIt locator) {
    locator.registerLazySingleton<FeesDatasource>(
      () => FeesDatasource(
        getActiveMempoolServerUsecase:
            locator<GetActiveMempoolServerUsecase>(),
        mempoolSettingsRepository: locator<MempoolSettingsRepository>(),
      ),
    );
  }

  static void registerRepositories(GetIt locator) {
    locator.registerLazySingleton<FeesRepository>(
      () => FeesRepository(feesDatasource: locator<FeesDatasource>()),
    );
  }

  static void registerUseCases(GetIt locator) {
    locator.registerFactory<GetNetworkFeesUsecase>(
      () => GetNetworkFeesUsecase(
        feesRepository: locator<FeesRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
  }
}
