import 'package:bb_mobile/core/electrum/data/datasources/electrum_server_datasource.dart';
import 'package:bb_mobile/core/electrum/data/repository/electrum_server_repository_impl.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/payjoin/data/datasources/payjoin_datasource.dart';
import 'package:bb_mobile/core/payjoin/data/repository/payjoin_repository_impl.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/file_storage_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/google_drive_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_remote_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/repository/file_system_repository_impl.dart';
import 'package:bb_mobile/core/recoverbull/data/repository/google_drive_repository_impl.dart';
import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/repositories/file_system_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/repositories/google_drive_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository_impl.dart';
import 'package:bb_mobile/core/seed/data/repository/word_list_repository_impl.dart';
import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/repositories/word_list_repository.dart';
import 'package:bb_mobile/core/settings/data/repository/settings_repository_impl.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/impl/hive_storage_datasource_impl.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/swaps/data/datasources/boltz_datasource.dart';
import 'package:bb_mobile/core/swaps/data/datasources/boltz_storage_datasource.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository_impl.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/tor/data/datasources/tor_datasource.dart';
import 'package:bb_mobile/core/tor/data/repository/tor_repository_impl.dart';
import 'package:bb_mobile/core/tor/domain/repositories/tor_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/repository/wallet_metadata_repository_impl.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/locator.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';

Future<void> registerRepositories() async {
  locator.registerSingletonWithDependencies<TorRepository>(
    () => TorRepositoryImpl(locator<TorDatasource>()),
    dependsOn: [TorDatasource],
  );
  locator.registerLazySingleton<GoogleDriveRepository>(
    () => GoogleDriveRepositoryImpl(
      locator<GoogleDriveAppDatasource>(),
    ),
  );
  // Wait for Tor dependencies to be ready
  // Register TorRepository after TorDatasource is registered
  // Use waitFor to ensure TorDatasource is ready before TorRepository is created
  await locator.isReady<TorRepository>();

  locator.registerSingletonWithDependencies<RecoverBullRepository>(
    () => RecoverBullRepositoryImpl(
      remoteDatasource: locator<RecoverBullRemoteDatasource>(),
      torRepository: locator<TorRepository>(),
    ),
    dependsOn: [TorRepository],
  );
  // await locator.isReady<RecoverBullRepository>();

  final walletMetadataBox =
      await Hive.openBox<String>(HiveBoxNameConstants.walletMetadata);
  locator.registerLazySingleton<WalletMetadataRepository>(
    () => WalletMetadataRepositoryImpl(
      source: WalletMetadataDatasource(
        walletMetadataStorage:
            HiveStorageDatasourceImpl<String>(walletMetadataBox),
      ),
    ),
  );
  final electrumServersBox =
      await Hive.openBox<String>(HiveBoxNameConstants.electrumServers);
  locator.registerLazySingleton<ElectrumServerRepository>(
    () => ElectrumServerRepositoryImpl(
      electrumServerDatasource: ElectrumServerDatasource(
        electrumServerStorage:
            HiveStorageDatasourceImpl<String>(electrumServersBox),
      ),
    ),
  );
  locator.registerLazySingleton<FileSystemRepository>(
    () => FileSystemRepositoryImpl(
      locator<FileStorageDatasource>(),
    ),
  );
  locator.registerLazySingleton<SeedRepository>(
    () => SeedRepositoryImpl(
      source: SeedDatasource(
        secureStorage: locator<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
      ),
    ),
  );
  final settingsBox = await Hive.openBox<String>(HiveBoxNameConstants.settings);
  locator.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(
      storage: HiveStorageDatasourceImpl<String>(settingsBox),
    ),
  );
  final pdkPayjoinsBox =
      await Hive.openBox<String>(HiveBoxNameConstants.pdkPayjoins);
  final pdkPayjoinDataSource = PayjoinDatasource(
    dio: Dio(),
    storage: HiveStorageDatasourceImpl<String>(pdkPayjoinsBox),
  );
  locator.registerLazySingleton<PayjoinRepository>(
    () => PayjoinRepositoryImpl(
      payjoinDatasource: pdkPayjoinDataSource,
    ),
  );
  locator.registerLazySingleton<SwapRepository>(
    () => BoltzSwapRepositoryImpl(
      boltz: BoltzDatasource(
        boltzStore: BoltzStorageDatasource(
          secureSwapStorage: locator<KeyValueStorageDatasource<String>>(
            instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
          ),
          localSwapStorage: locator<KeyValueStorageDatasource<String>>(
            instanceName: LocatorInstanceNameConstants
                .boltzSwapsHiveStorageDatasourceInstanceName,
          ),
        ),
      ),
    ),
    instanceName: LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
  );

  locator.registerLazySingleton<SwapRepository>(
    () => BoltzSwapRepositoryImpl(
      boltz: BoltzDatasource(
        url: ApiServiceConstants.boltzTestnetUrlPath,
        boltzStore: BoltzStorageDatasource(
          secureSwapStorage: locator<KeyValueStorageDatasource<String>>(
            instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
          ),
          localSwapStorage: locator<KeyValueStorageDatasource<String>>(
            instanceName: LocatorInstanceNameConstants
                .boltzSwapsHiveStorageDatasourceInstanceName,
          ),
        ),
      ),
    ),
    instanceName:
        LocatorInstanceNameConstants.boltzTestnetSwapRepositoryInstanceName,
  );

  locator.registerLazySingleton<WordListRepository>(
    () => WordListRepositoryImpl(),
  );
}
