import 'package:bb_mobile/core/mempool/application/usecases/delete_custom_mempool_server_usecase.dart';
import 'package:bb_mobile/core/mempool/application/usecases/get_active_mempool_server_usecase.dart';
import 'package:bb_mobile/core/mempool/application/usecases/load_mempool_server_data_usecase.dart';
import 'package:bb_mobile/core/mempool/application/usecases/set_custom_mempool_server_usecase.dart';
import 'package:bb_mobile/core/mempool/application/usecases/update_mempool_settings_usecase.dart';
import 'package:bb_mobile/core/mempool/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/mempool/domain/ports/mempool_server_validator_port.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_server_repository.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_settings_repository.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/datasources/mempool_server_storage_datasource.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/datasources/mempool_settings_storage_datasource.dart';
import 'package:bb_mobile/core/mempool/interface_adapters/environment/settings_environment_adapter.dart';
import 'package:bb_mobile/core/mempool/interface_adapters/repositories/drift_mempool_server_repository.dart';
import 'package:bb_mobile/core/mempool/interface_adapters/repositories/drift_mempool_settings_repository.dart';
import 'package:bb_mobile/core/mempool/interface_adapters/validators/http_mempool_server_validator.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/mempool_url.dart';
import 'package:get_it/get_it.dart';

class MempoolLocator {
  static Future<void> registerDatasources(GetIt locator) async {
    locator.registerLazySingleton<MempoolServerStorageDatasource>(
      () => MempoolServerStorageDatasource(sqlite: locator<SqliteDatabase>()),
    );
    locator.registerLazySingleton<MempoolSettingsStorageDatasource>(
      () => MempoolSettingsStorageDatasource(sqlite: locator<SqliteDatabase>()),
    );
  }

  static void registerRepositories(GetIt locator) {
    locator.registerLazySingleton<MempoolServerRepository>(
      () => DriftMempoolServerRepository(
        mempoolServerStorageDatasource:
            locator<MempoolServerStorageDatasource>(),
      ),
    );

    locator.registerLazySingleton<MempoolSettingsRepository>(
      () => DriftMempoolSettingsRepository(
        mempoolSettingsStorageDatasource:
            locator<MempoolSettingsStorageDatasource>(),
      ),
    );
  }

  static void registerPorts(GetIt locator) {
    locator.registerLazySingleton<MempoolServerValidatorPort>(
      () => HttpMempoolServerValidator(),
    );

    locator.registerLazySingleton<MempoolEnvironmentPort>(
      () => SettingsEnvironmentAdapter(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<LoadMempoolServerDataUsecase>(
      () => LoadMempoolServerDataUsecase(
        serverRepository: locator<MempoolServerRepository>(),
        settingsRepository: locator<MempoolSettingsRepository>(),
        environmentPort: locator<MempoolEnvironmentPort>(),
      ),
    );

    locator.registerFactory<GetActiveMempoolServerUsecase>(
      () => GetActiveMempoolServerUsecase(
        serverRepository: locator<MempoolServerRepository>(),
      ),
    );

    locator.registerFactory<SetCustomMempoolServerUsecase>(
      () => SetCustomMempoolServerUsecase(
        serverRepository: locator<MempoolServerRepository>(),
        validator: locator<MempoolServerValidatorPort>(),
        environmentPort: locator<MempoolEnvironmentPort>(),
      ),
    );

    locator.registerFactory<DeleteCustomMempoolServerUsecase>(
      () => DeleteCustomMempoolServerUsecase(
        serverRepository: locator<MempoolServerRepository>(),
        environmentPort: locator<MempoolEnvironmentPort>(),
      ),
    );

    locator.registerFactory<UpdateMempoolSettingsUsecase>(
      () => UpdateMempoolSettingsUsecase(
        settingsRepository: locator<MempoolSettingsRepository>(),
        environmentPort: locator<MempoolEnvironmentPort>(),
      ),
    );
  }

  static void registerServices(GetIt locator) {
    locator.registerLazySingleton<MempoolUrlService>(
      () => MempoolUrlService(
        getActiveMempoolServerUsecase: locator<GetActiveMempoolServerUsecase>(),
      ),
    );
  }
}
