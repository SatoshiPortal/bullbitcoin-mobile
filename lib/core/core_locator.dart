import 'package:bb_mobile/core/data/datasources/bitcoin_price_datasource.dart';
import 'package:bb_mobile/core/data/datasources/boltz_datasource.dart';
import 'package:bb_mobile/core/data/datasources/boltz_storage_datasource.dart';
import 'package:bb_mobile/core/data/datasources/electrum_server_datasource.dart';
import 'package:bb_mobile/core/data/datasources/file_storage_datasource.dart';
import 'package:bb_mobile/core/data/datasources/google_drive_datasource.dart';
import 'package:bb_mobile/core/data/datasources/key_value_storage/impl/hive_storage_datasource_impl.dart';
import 'package:bb_mobile/core/data/datasources/key_value_storage/impl/secure_storage_data_source_impl.dart';
import 'package:bb_mobile/core/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/data/datasources/payjoin_datasource.dart';
import 'package:bb_mobile/core/data/datasources/recoverbull_remote_datasource.dart';
import 'package:bb_mobile/core/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/data/datasources/tor_datasource.dart';
import 'package:bb_mobile/core/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/data/repositories/boltz_swap_repository_impl.dart';
import 'package:bb_mobile/core/data/repositories/electrum_server_repository_impl.dart';
import 'package:bb_mobile/core/data/repositories/exchange_rate_repository_impl.dart';
import 'package:bb_mobile/core/data/repositories/file_system_repository_impl.dart';
import 'package:bb_mobile/core/data/repositories/google_drive_repository_impl.dart';
import 'package:bb_mobile/core/data/repositories/payjoin_repository_impl.dart';
import 'package:bb_mobile/core/data/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/core/data/repositories/seed_repository_impl.dart';
import 'package:bb_mobile/core/data/repositories/settings_repository_impl.dart';
import 'package:bb_mobile/core/data/repositories/tor_repository_impl.dart';
import 'package:bb_mobile/core/data/repositories/wallet_metadata_repository_impl.dart';
import 'package:bb_mobile/core/data/services/mnemonic_seed_factory_impl.dart';
import 'package:bb_mobile/core/data/services/payjoin_watcher_service_impl.dart';
import 'package:bb_mobile/core/data/services/swap_watcher_impl.dart';
import 'package:bb_mobile/core/data/services/wallet_manager_service_impl.dart';
import 'package:bb_mobile/core/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/domain/repositories/file_system_repository.dart';
import 'package:bb_mobile/core/domain/repositories/google_drive_repository.dart';
import 'package:bb_mobile/core/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/domain/repositories/tor_repository.dart';
import 'package:bb_mobile/core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/core/domain/repositories/word_list_repository.dart';
import 'package:bb_mobile/core/domain/services/mnemonic_seed_factory.dart';
import 'package:bb_mobile/core/domain/services/payjoin_watcher_service.dart';
import 'package:bb_mobile/core/domain/services/swap_watcher_service.dart';
import 'package:bb_mobile/core/domain/services/wallet_manager_service.dart';
import 'package:bb_mobile/core/domain/usecases/build_transaction_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/convert_currency_to_sats_amount_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/create_backup_key_from_default_seed_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/fetch_backup_from_file_system_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/find_mnemonic_words_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/get_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/get_currency_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/get_environment_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/get_hide_amounts_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/get_language_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/get_payjoin_updates_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/google_drive/disconnect_google_drive_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/receive_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/select_file_path_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/select_folder_path_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/receive/domain/usecases/create_receive_swap_use_case.dart';
import 'package:bb_mobile/features/recover_wallet/domain/usecases/restore_encrypted_vault_from_backup_key_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

class CoreLocator {
  static Future<void> setup() async {
    // Data sources
    //  - Tor
    if (!locator.isRegistered<TorDatasource>()) {
      // Register TorDatasource as a singleton async
      // This ensures Tor is properly initialized before it's used
      locator.registerSingletonAsync<TorDatasource>(
        () async {
          final tor = await TorDatasource.init();
          return tor;
        },
      );
    }
    await locator.isReady<TorDatasource>();
    //  - Secure storage
    locator.registerLazySingleton<KeyValueStorageDatasource<String>>(
      () => SecureStorageDatasourceImpl(
        const FlutterSecureStorage(),
      ),
      instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
    );
    //  - Bull Bitcoin API
    final bbApiDatasource = BitcoinPriceDatasource(
      bullBitcoinHttpClient: Dio(
        BaseOptions(baseUrl: 'https://api.bullbitcoin.com'),
      ),
    );
    locator.registerLazySingleton<BitcoinPriceDatasource>(
      () => bbApiDatasource,
    );
    //  - Swaps
    final boltzSwapsBox =
        await Hive.openBox<String>(HiveBoxNameConstants.boltzSwaps);
    locator.registerLazySingleton<KeyValueStorageDatasource<String>>(
      () => HiveStorageDatasourceImpl<String>(boltzSwapsBox),
      instanceName: LocatorInstanceNameConstants
          .boltzSwapsHiveStorageDatasourceInstanceName,
    );

    // Repositories
    // Register TorRepository right after TorDatasource
    // - Google Drive Datasource
    locator.registerLazySingleton<GoogleDriveAppDatasource>(
      () => GoogleDriveAppDatasource(),
    );

    // - RecoverBullRemoteDatasource
    locator.registerLazySingleton<RecoverBullRemoteDatasource>(
      () => RecoverBullRemoteDatasource(
        address: Uri.parse(ApiServiceConstants.bullBitcoinKeyServerApiUrlPath),
      ),
    );
    // - FileStorageDataSource

    locator.registerLazySingleton<FileStorageDatasource>(
      () => FileStorageDatasource(filePicker: FilePicker.platform),
    );

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
    final settingsBox =
        await Hive.openBox<String>(HiveBoxNameConstants.settings);
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
              instanceName:
                  LocatorInstanceNameConstants.secureStorageDatasource,
            ),
            localSwapStorage: locator<KeyValueStorageDatasource<String>>(
              instanceName: LocatorInstanceNameConstants
                  .boltzSwapsHiveStorageDatasourceInstanceName,
            ),
          ),
        ),
      ),
      instanceName:
          LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
    );
    // add swap watcher service
    locator.registerLazySingleton<SwapWatcherService>(
      () => SwapWatcherServiceImpl(
        walletManager: locator<WalletManagerService>(),
        boltzRepo: locator<SwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ) as BoltzSwapRepositoryImpl,
      ),
      instanceName: LocatorInstanceNameConstants.boltzSwapWatcherInstanceName,
    );
    locator.registerLazySingleton<SwapRepository>(
      () => BoltzSwapRepositoryImpl(
        boltz: BoltzDatasource(
          url: ApiServiceConstants.boltzTestnetUrlPath,
          boltzStore: BoltzStorageDatasource(
            secureSwapStorage: locator<KeyValueStorageDatasource<String>>(
              instanceName:
                  LocatorInstanceNameConstants.secureStorageDatasource,
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
    // add swap watcher service
    locator.registerLazySingleton<SwapWatcherService>(
      () => SwapWatcherServiceImpl(
        walletManager: locator<WalletManagerService>(),
        boltzRepo: locator<SwapRepository>(
          instanceName: LocatorInstanceNameConstants
              .boltzTestnetSwapRepositoryInstanceName,
        ) as BoltzSwapRepositoryImpl,
      ),
      instanceName:
          LocatorInstanceNameConstants.boltzTestnetSwapWatcherInstanceName,
    );

    // Factories, managers or services responsible for handling specific logic
    locator.registerLazySingleton<MnemonicSeedFactory>(
      () => const MnemonicSeedFactoryImpl(),
    );
    locator.registerLazySingleton<WalletManagerService>(
      () => WalletManagerServiceImpl(
        walletMetadataRepository: locator<WalletMetadataRepository>(),
        seedRepository: locator<SeedRepository>(),
        electrumServerRepository: locator<ElectrumServerRepository>(),
      ),
    );
    locator.registerLazySingleton<PayjoinWatcherService>(
      () => PayjoinWatcherServiceImpl(
        payjoinRepository: locator<PayjoinRepository>(),
        electrumServerRepository: locator<ElectrumServerRepository>(),
        settingsRepository: locator<SettingsRepository>(),
        walletManagerService: locator<WalletManagerService>(),
      ),
    );

    // Use cases
    locator.registerFactory<CreateBackupKeyFromDefaultSeedUsecase>(
      () => CreateBackupKeyFromDefaultSeedUsecase(
        seedRepository: locator<SeedRepository>(),
        walletMetadataRepository: locator<WalletMetadataRepository>(),
      ),
    );
    locator.registerFactory<ConnectToGoogleDriveUsecase>(
      () => ConnectToGoogleDriveUsecase(
        locator<GoogleDriveRepository>(),
      ),
    );
    locator.registerFactory<FetchLatestGoogleDriveBackupUsecase>(
      () => FetchLatestGoogleDriveBackupUsecase(
        locator<GoogleDriveRepository>(),
      ),
    );
    locator.registerFactory<DisconnectFromGoogleDriveUsecase>(
      () => DisconnectFromGoogleDriveUsecase(
        locator<GoogleDriveRepository>(),
      ),
    );
    locator.registerFactory<SelectFileFromPathUsecase>(
      () => SelectFileFromPathUsecase(
        locator<FileSystemRepository>(),
      ),
    );
    locator.registerFactory<SelectFolderPathUsecase>(
      () => SelectFolderPathUsecase(
        locator<FileSystemRepository>(),
      ),
    );
    locator.registerFactory<FetchBackupFromFileSystemUsecase>(
      () => FetchBackupFromFileSystemUsecase(),
    );

    locator.registerFactory<RestoreEncryptedVaultFromBackupKeyUsecase>(
      () => RestoreEncryptedVaultFromBackupKeyUsecase(
        recoverBullRepository: locator<RecoverBullRepository>(),
        walletManagerService: locator<WalletManagerService>(),
        walletMetadataRepository: locator<WalletMetadataRepository>(),
      ),
    );
    locator.registerFactory<FindMnemonicWordsUsecase>(
      () => FindMnemonicWordsUsecase(
        wordListRepository: locator<WordListRepository>(),
      ),
    );
    locator.registerFactory<GetEnvironmentUsecase>(
      () => GetEnvironmentUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<GetBitcoinUnitUsecase>(
      () => GetBitcoinUnitUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<GetHideAmountsUsecase>(
      () => GetHideAmountsUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<GetLanguageUsecase>(
      () => GetLanguageUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<GetCurrencyUsecase>(
      () => GetCurrencyUsecase(
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<GetWalletsUsecase>(
      () => GetWalletsUsecase(
        settingsRepository: locator<SettingsRepository>(),
        walletManager: locator<WalletManagerService>(),
      ),
    );
    locator.registerFactory<ReceiveWithPayjoinUsecase>(
      () => ReceiveWithPayjoinUsecase(
        payjoinRepository: locator<PayjoinRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<SendWithPayjoinUsecase>(
      () => SendWithPayjoinUsecase(
        payjoinRepository: locator<PayjoinRepository>(),
      ),
    );
    locator.registerFactory<GetPayjoinUpdatesUsecase>(
      () => GetPayjoinUpdatesUsecase(
        payjoinWatcherService: locator<PayjoinWatcherService>(),
      ),
    );
    locator.registerFactory<CreateReceiveSwapUsecase>(
      () => CreateReceiveSwapUsecase(
        walletManager: locator<WalletManagerService>(),
        swapRepository: locator<SwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        swapRepositoryTestnet: locator<SwapRepository>(
          instanceName: LocatorInstanceNameConstants
              .boltzTestnetSwapRepositoryInstanceName,
        ),
        seedRepository: locator<SeedRepository>(),
      ),
    );
    locator.registerFactory<BuildTransactionUsecase>(
      () => BuildTransactionUsecase(
        payjoinRepository: locator<PayjoinRepository>(),
        walletManagerService: locator<WalletManagerService>(),
      ),
    );
    final exchangeRateRepository = ExchangeRateRepositoryImpl(
      bitcoinPriceDatasource: locator<BitcoinPriceDatasource>(),
    );
    locator.registerFactory<GetAvailableCurrenciesUsecase>(
      () => GetAvailableCurrenciesUsecase(
        exchangeRateRepository: exchangeRateRepository,
      ),
    );
    locator.registerFactory<ConvertSatsToCurrencyAmountUsecase>(
      () => ConvertSatsToCurrencyAmountUsecase(
        exchangeRateRepository: exchangeRateRepository,
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<ConvertCurrencyToSatsAmountUsecase>(
      () => ConvertCurrencyToSatsAmountUsecase(
        exchangeRateRepository: exchangeRateRepository,
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<WatchSwapUsecase>(
      () => WatchSwapUsecase(
        watcherService: locator<SwapWatcherService>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapWatcherInstanceName,
        ),
      ),
    );
  }
}
