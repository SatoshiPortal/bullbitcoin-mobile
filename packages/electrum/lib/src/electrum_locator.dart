import 'package:electrum/src/data/datasources/electrum_remote_datasource.dart';
import 'package:electrum/src/data/drift_electrum_server_repository.dart';
import 'package:electrum/src/data/drift_electrum_settings_repository.dart';
import 'package:electrum/src/data/drift_electrum_transaction_repository.dart';
import 'package:electrum/src/data/electrum_defaults_provisioner.dart';
import 'package:electrum/src/data/electrum_server_storage_datasource.dart';
import 'package:electrum/src/data/electrum_servers_adapter.dart';
import 'package:electrum/src/data/electrum_settings_storage_datasource.dart';
import 'package:electrum/src/data/electrum_socket_connector.dart';
import 'package:electrum/src/data/electrum_tor_session_adapter.dart';
import 'package:electrum/src/data/server_status_adapter.dart';
import 'package:electrum/src/data/wallet_connection_policy_impl.dart';
import 'package:electrum/src/domain/electrum_preferences.dart';
import 'package:electrum/src/domain/ports/electrum_servers_port.dart';
import 'package:electrum/src/domain/ports/electrum_tor_session_port.dart';
import 'package:electrum/src/domain/ports/environment_port.dart';
import 'package:electrum/src/domain/ports/server_status_port.dart';
import 'package:electrum/src/domain/repositories/electrum_server_repository.dart';
import 'package:electrum/src/domain/repositories/electrum_settings_repository.dart';
import 'package:electrum/src/domain/repositories/electrum_transaction_repository.dart';
import 'package:electrum/src/domain/usecases/add_custom_server_usecase.dart';
import 'package:electrum/src/domain/usecases/delete_custom_server_usecase.dart';
import 'package:electrum/src/domain/usecases/has_active_custom_bitcoin_onion_server_usecase.dart';
import 'package:electrum/src/domain/usecases/load_electrum_server_data_usecase.dart';
import 'package:electrum/src/domain/usecases/set_advanced_electrum_options_usecase.dart';
import 'package:electrum/src/domain/usecases/set_custom_servers_priority_usecase.dart';
import 'package:electrum/src/electrum.dart';
import 'package:sync/sync.dart' show WalletConnectionPort;
import 'package:drift/drift.dart' show GeneratedDatabase;
import 'package:get_it/get_it.dart';
import 'package:bull_tor/tor.dart' show Tor;

class ElectrumLocator {
  static void registerDatasources(
    GetIt locator,
    GeneratedDatabase Function() database,
  ) {
    locator.registerLazySingleton<ElectrumDefaultsProvisioner>(
      () => ElectrumDefaultsProvisioner(database()),
    );
    locator.registerLazySingleton<ElectrumServerStorageDatasource>(
      () => ElectrumServerStorageDatasource(sqlite: database()),
    );
    locator.registerLazySingleton<ElectrumSettingsStorageDatasource>(
      () => ElectrumSettingsStorageDatasource(sqlite: database()),
    );
    locator.registerLazySingleton<ElectrumRemoteDatasource>(
      () => ElectrumRemoteDatasource(
        sqlite: database(),
        socketConnector: locator<ElectrumSocketConnector>(),
      ),
    );
    locator.registerLazySingleton<ElectrumSocketConnector>(
      ElectrumSocketConnector.new,
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

  static void registerPorts(
    GetIt locator, {
    required EnvironmentPort environment,
    required Future<ElectrumPreferences> Function() readPreferences,
    required Tor Function() tor,
  }) {
    locator.registerLazySingleton<EnvironmentPort>(() => environment);
    locator.registerLazySingleton<ServerStatusPort>(
      () => ServerStatusAdapter(locator<ElectrumSocketConnector>()),
    );
    locator.registerLazySingleton<ElectrumTorSessionPort>(
      () => ElectrumTorSessionAdapter(tor),
    );
    locator.registerLazySingleton<ElectrumServersPort>(
      () => ElectrumServersAdapter(
        serverRepository: locator<ElectrumServerRepository>(),
        settingsRepository: locator<ElectrumSettingsRepository>(),
        readPreferences: readPreferences,
        torSessionPort: locator<ElectrumTorSessionPort>(),
      ),
    );
    locator.registerLazySingleton<Electrum>(
      () => Electrum(
        serversPort: locator<ElectrumServersPort>(),
        repository: locator<ElectrumTransactionRepository>(),
      ),
    );
    locator.registerLazySingleton<WalletConnectionPort>(
      () => WalletConnectionPolicyImpl(locator<ElectrumServersPort>()),
    );
  }

  static void registerUsecases(
    GetIt locator,
    Future<ElectrumPreferences> Function() readPreferences,
  ) {
    locator.registerFactory<HasActiveCustomBitcoinOnionServerUsecase>(
      () => HasActiveCustomBitcoinOnionServerUsecase(
        locator<ElectrumServerRepository>(),
        locator<EnvironmentPort>(),
      ),
    );
    locator.registerFactory<AddCustomServerUsecase>(
      () => AddCustomServerUsecase(
        electrumServerRepository: locator<ElectrumServerRepository>(),
        electrumSettingsRepository: locator<ElectrumSettingsRepository>(),
        serverStatusPort: locator<ServerStatusPort>(),
        torSessionPort: locator<ElectrumTorSessionPort>(),
        readPreferences: readPreferences,
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
        torSessionPort: locator<ElectrumTorSessionPort>(),
        readPreferences: readPreferences,
      ),
    );
    locator.registerFactory<SetAdvancedElectrumOptionsUsecase>(
      () => SetAdvancedElectrumOptionsUsecase(
        electrumSettingsRepository: locator<ElectrumSettingsRepository>(),
      ),
    );
  }
}
