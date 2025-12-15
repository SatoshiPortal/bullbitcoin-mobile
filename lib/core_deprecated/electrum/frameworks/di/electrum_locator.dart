import 'package:bb_mobile/core_deprecated/electrum/application/usecases/add_custom_server_usecase.dart';
import 'package:bb_mobile/core_deprecated/electrum/application/usecases/check_for_online_electrum_servers_usecase.dart';
import 'package:bb_mobile/core_deprecated/electrum/application/usecases/delete_custom_server_usecase.dart';
import 'package:bb_mobile/core_deprecated/electrum/application/usecases/get_electrum_servers_to_use_usecase.dart';
import 'package:bb_mobile/core_deprecated/electrum/application/usecases/load_electrum_server_data_usecase.dart';
import 'package:bb_mobile/core_deprecated/electrum/application/usecases/set_advanced_electrum_options_usecase.dart';
import 'package:bb_mobile/core_deprecated/electrum/application/usecases/set_custom_servers_priority_usecase.dart';
import 'package:bb_mobile/core_deprecated/electrum/domain/ports/environment_port.dart';
import 'package:bb_mobile/core_deprecated/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core_deprecated/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core_deprecated/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/core_deprecated/electrum/frameworks/drift/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core_deprecated/electrum/frameworks/drift/datasources/electrum_settings_storage_datasource.dart';
import 'package:bb_mobile/core_deprecated/electrum/frameworks/socket/datasources/socket_connectivity_datasource.dart';
import 'package:bb_mobile/core_deprecated/electrum/interface_adapters/adapters/environment_adapter.dart';
import 'package:bb_mobile/core_deprecated/electrum/interface_adapters/adapters/server_status_adapter.dart';
import 'package:bb_mobile/core_deprecated/electrum/interface_adapters/repositories/drift_electrum_server_repository.dart';
import 'package:bb_mobile/core_deprecated/electrum/interface_adapters/repositories/drift_electrum_settings_repository.dart';
import 'package:bb_mobile/core_deprecated/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core_deprecated/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/infra/database/sqlite_database.dart';
import 'package:get_it/get_it.dart';

class ElectrumLocator {
  static Future<void> registerDatasources(GetIt locator) async {
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

  static void registerRepositories(GetIt locator) {
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

  static void registerPorts(GetIt locator) {
    locator.registerLazySingleton<EnvironmentPort>(
      () =>
          EnvironmentAdapter(getSettingsUsecase: locator<GetSettingsUsecase>()),
    );
    locator.registerLazySingleton<ServerStatusPort>(
      () => ServerStatusAdapter(
        socketDatasource: locator<SocketConnectivityDatasource>(),
      ),
    );
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<AddCustomServerUsecase>(
      () => AddCustomServerUsecase(
        electrumServerRepository: locator<ElectrumServerRepository>(),
        serverStatusPort: locator<ServerStatusPort>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<CheckForOnlineElectrumServersUsecase>(
      () => CheckForOnlineElectrumServersUsecase(
        environmentPort: locator<EnvironmentPort>(),
        electrumServerRepository: locator<ElectrumServerRepository>(),
        serverStatusPort: locator<ServerStatusPort>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<SetCustomServersPriorityUsecase>(
      () => SetCustomServersPriorityUsecase(
        electrumServerRepository: locator<ElectrumServerRepository>(),
      ),
    );
    locator.registerFactory<DeleteCustomServerUsecase>(
      () => DeleteCustomServerUsecase(
        electrumServerRepository: locator<ElectrumServerRepository>(),
      ),
    );
    locator.registerFactory<GetElectrumServersToUseUsecase>(
      () => GetElectrumServersToUseUsecase(
        electrumServerRepository: locator<ElectrumServerRepository>(),
        electrumSettingsRepository: locator<ElectrumSettingsRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<LoadElectrumServerDataUsecase>(
      () => LoadElectrumServerDataUsecase(
        electrumServerRepository: locator<ElectrumServerRepository>(),
        electrumSettingsRepository: locator<ElectrumSettingsRepository>(),
        environmentPort: locator<EnvironmentPort>(),
        serverStatusPort: locator<ServerStatusPort>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<SetAdvancedElectrumOptionsUsecase>(
      () => SetAdvancedElectrumOptionsUsecase(
        electrumSettingsRepository: locator<ElectrumSettingsRepository>(),
      ),
    );
  }
}
