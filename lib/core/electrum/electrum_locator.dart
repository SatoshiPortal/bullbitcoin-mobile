import 'package:bb_mobile/core/electrum/application/usecases_old/check_electrum_server_connectivity_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases_old/delete_electrum_server_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases_old/get_all_electrum_servers_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases_old/get_prioritized_server_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases_old/reorder_custom_servers_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases_old/store_electrum_server_settings_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases_old/try_connection_with_fallback_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases_old/update_electrum_server_settings_usecase.dart';
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
    locator.registerLazySingleton<ReorderCustomServersUsecase>(
      () => ReorderCustomServersUsecase(
        repository: locator<ElectrumServerRepository>(),
      ),
    );
  }
}
