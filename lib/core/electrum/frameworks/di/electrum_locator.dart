import 'package:bb_mobile/core/electrum/application/usecases/add_custom_server_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/check_for_online_electrum_servers_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/delete_custom_server_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/get_electrum_servers_to_broadcast_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/load_electrum_server_data_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_settings_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/frameworks/socket/datasources/socket_connectivity_datasource.dart';
import 'package:bb_mobile/core/electrum/interface_adapters/adapters/server_status_adapter.dart';
import 'package:bb_mobile/core/electrum/interface_adapters/facades/environment_facade.dart';
import 'package:bb_mobile/core/electrum/interface_adapters/repositories/drift_electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/interface_adapters/repositories/drift_electrum_settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/locator.dart';

class ElectrumLocator {
  static Future<void> registerDatasources() async {
    locator.registerLazySingleton<ElectrumServerStorageDatasource>(
      () => ElectrumServerStorageDatasource(sqlite: locator<SqliteDatabase>()),
    );
    locator.registerLazySingleton<ElectrumSettingsStorageDatasource>(
      () =>
          ElectrumSettingsStorageDatasource(sqlite: locator<SqliteDatabase>()),
    );
    locator.registerLazySingleton<SocketConnectivityDatasource>(
      () => const SocketConnectivityDatasource(),
    );
  }

  static void registerRepositories() {
    locator.registerLazySingleton<ElectrumServerRepository>(
      () => DriftElectrumServerRepository(
        electrumServerStorageDatasource:
            locator<ElectrumServerStorageDatasource>(),
      ),
    );

    locator.registerLazySingleton<ElectrumSettingsRepository>(
      () => DriftElectrumSettingsRepository(
        electrumSettingsStorageDatasource:
            locator<ElectrumSettingsStorageDatasource>(),
      ),
    );
  }

  static void registerPorts() {
    locator.registerLazySingleton<EnvironmentPort>(
      () =>
          EnvironmentFacade(getSettingsUsecase: locator<GetSettingsUsecase>()),
    );
    locator.registerLazySingleton<ServerStatusPort>(
      () => ServerStatusAdapter(
        socketDatasource: locator<SocketConnectivityDatasource>(),
      ),
    );
  }

  static void registerUsecases() {
    locator.registerFactory<AddCustomServerUsecase>(
      () => AddCustomServerUsecase(
        electrumServerRepository: locator<ElectrumServerRepository>(),
        serverStatusPort: locator<ServerStatusPort>(),
      ),
    );
    locator.registerFactory<CheckForOnlineElectrumServersUsecase>(
      () => CheckForOnlineElectrumServersUsecase(
        environmentPort: locator<EnvironmentPort>(),
        electrumServerRepository: locator<ElectrumServerRepository>(),
        serverStatusPort: locator<ServerStatusPort>(),
      ),
    );
    locator.registerFactory<DeleteCustomServerUsecase>(
      () => DeleteCustomServerUsecase(
        electrumServerRepository: locator<ElectrumServerRepository>(),
      ),
    );
    locator.registerFactory<GetElectrumServersToBroadcastUsecase>(
      () => GetElectrumServersToBroadcastUsecase(
        electrumServerRepository: locator<ElectrumServerRepository>(),
        electrumSettingsRepository: locator<ElectrumSettingsRepository>(),
      ),
    );
    locator.registerFactory<LoadElectrumServerDataUsecase>(
      () => LoadElectrumServerDataUsecase(
        electrumServerRepository: locator<ElectrumServerRepository>(),
        electrumSettingsRepository: locator<ElectrumSettingsRepository>(),
        environmentPort: locator<EnvironmentPort>(),
        serverStatusPort: locator<ServerStatusPort>(),
      ),
    );
  }
}
