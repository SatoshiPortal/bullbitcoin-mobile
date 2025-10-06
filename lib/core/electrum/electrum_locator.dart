import 'package:bb_mobile/core/electrum/data/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/data/repository/electrum_server_repository_impl.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/check_electrum_server_connectivity_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/delete_electrum_server_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/get_all_electrum_servers_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/get_prioritized_server_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/store_electrum_server_settings_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/try_connection_with_fallback_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/usecases/update_electrum_server_settings_usecase.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/locator.dart';

class ElectrumLocator {
  static Future<void> registerDatasources() async {
    locator.registerLazySingleton<ElectrumServerStorageDatasource>(
      () => ElectrumServerStorageDatasource(sqlite: locator<SqliteDatabase>()),
    );
  }

  static void registerRepositories() {
    locator.registerLazySingleton<ElectrumServerRepository>(
      () => ElectrumServerRepository(
        electrumServerStorageDatasource:
            locator<ElectrumServerStorageDatasource>(),
      ),
    );
  }

  static void registerUsecases() {
    locator.registerLazySingleton<CheckElectrumServerConnectivityUsecase>(
      () => CheckElectrumServerConnectivityUsecase(
        electrumServerRepository: locator<ElectrumServerRepository>(),
      ),
    );
    locator.registerLazySingleton<StoreElectrumServerSettingsUsecase>(
      () => StoreElectrumServerSettingsUsecase(
        repository: locator<ElectrumServerRepository>(),
      ),
    );
    locator.registerLazySingleton<UpdateElectrumServerSettingsUsecase>(
      () => UpdateElectrumServerSettingsUsecase(
        repository: locator<ElectrumServerRepository>(),
      ),
    );
    locator.registerLazySingleton<GetAllElectrumServersUsecase>(
      () => GetAllElectrumServersUsecase(
        electrumServerRepository: locator<ElectrumServerRepository>(),
      ),
    );
    locator.registerLazySingleton<TryConnectionWithFallbackUsecase>(
      () => TryConnectionWithFallbackUsecase(
        electrumServerRepository: locator<ElectrumServerRepository>(),
      ),
    );
    locator.registerLazySingleton<GetPrioritizedServerUsecase>(
      () => GetPrioritizedServerUsecase(
        electrumServerRepository: locator<ElectrumServerRepository>(),
      ),
    );
    locator.registerLazySingleton<DeleteElectrumServerUsecase>(
      () => DeleteElectrumServerUsecase(
        electrumServerRepository: locator<ElectrumServerRepository>(),
      ),
    );
  }
}
