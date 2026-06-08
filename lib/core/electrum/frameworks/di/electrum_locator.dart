import 'package:bb_mobile/core/electrum/application/usecases/add_custom_server_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/delete_custom_server_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/load_electrum_server_data_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/set_advanced_electrum_options_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/set_custom_servers_priority_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core/electrum/electrum_facade.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_transaction_repository.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_remote_datasource.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_settings_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/adapters/drift_electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/adapters/drift_electrum_settings_repository.dart';
import 'package:bb_mobile/core/electrum/adapters/drift_electrum_transaction_repository.dart';
import 'package:bb_mobile/core/electrum/adapters/electrum_servers_adapter.dart';
import 'package:bb_mobile/core/electrum/adapters/electrum_transaction_port_adapter.dart';
import 'package:bb_mobile/core/electrum/adapters/environment_adapter.dart';
import 'package:bb_mobile/core/electrum/adapters/server_status_adapter.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/transactions/domain/transaction_port.dart';
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
    locator.registerLazySingleton<ElectrumRemoteDatasource>(
      () => ElectrumRemoteDatasource(sqlite: locator<SqliteDatabase>()),
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

    locator.registerLazySingleton<ElectrumTransactionRepository>(
      () => DriftElectrumTransactionRepository(
        datasource: locator<ElectrumRemoteDatasource>(),
      ),
    );
  }

  static void registerPorts(GetIt locator) {
    locator.registerLazySingleton<EnvironmentPort>(
      () => EnvironmentAdapter(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerLazySingleton<ServerStatusPort>(
      () => const ServerStatusAdapter(),
    );
    locator.registerLazySingleton<ElectrumServersPort>(
      () => ElectrumServersAdapter(
        serverRepository: locator<ElectrumServerRepository>(),
        settingsRepository: locator<ElectrumSettingsRepository>(),
        appSettingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerLazySingleton<TransactionPort>(
      () => ElectrumTransactionPortAdapter(
        serversPort: locator<ElectrumServersPort>(),
        repository: locator<ElectrumTransactionRepository>(),
        environmentPort: locator<EnvironmentPort>(),
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

  static void registerFacades(GetIt locator) {
    locator.registerLazySingleton<ElectrumFacade>(
      () => ElectrumFacade(
        electrumServerRepository: locator<ElectrumServerRepository>(),
        electrumSettingsRepository: locator<ElectrumSettingsRepository>(),
      ),
    );
  }
}
