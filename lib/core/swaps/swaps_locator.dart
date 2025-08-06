import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';
import 'package:bb_mobile/core/fees/data/fees_repository.dart';
import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/swaps/data/datasources/boltz_datasource.dart';
import 'package:bb_mobile/core/swaps/data/datasources/boltz_storage_datasource.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/data/services/swap_watcher.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/auto_swap_execution_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/create_chain_swap_to_external_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/create_chain_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/decode_invoice_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_limits_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swaps_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/process_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/restart_swap_watcher_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/save_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/update_paid_chain_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/locator.dart';

class SwapsLocator {
  static Future<void> registerDatasources() async {
    locator.registerLazySingleton<BoltzStorageDatasource>(
      () => BoltzStorageDatasource(
        secureSwapStorage: locator<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
        localSwapStorage: locator<SqliteDatabase>(),
      ),
    );
  }

  static void registerRepositories() {
    locator.registerLazySingleton<BoltzSwapRepository>(
      () => BoltzSwapRepository(
        boltz: BoltzDatasource(
          url: ApiServiceConstants.boltzTestnetUrlPath,
          boltzStore: locator<BoltzStorageDatasource>(),
        ),
        isTestnet: true,
      ),
      instanceName:
          LocatorInstanceNameConstants
              .boltzTestnetSwapRepositoryInstanceName,
    );

    locator.registerLazySingleton<BoltzSwapRepository>(
      () => BoltzSwapRepository(
        boltz: BoltzDatasource(boltzStore: locator<BoltzStorageDatasource>()),
        isTestnet: false,
      ),
      instanceName:
          LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
    );
  }

  static void registerServices() {
    locator.registerLazySingleton<SwapWatcherService>(
      () => SwapWatcherService(
        boltzRepo: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        walletAddressRepository: locator<WalletAddressRepository>(),
        settingsRepository: locator<SettingsRepository>(),
        feesRepository: locator<FeesRepository>(),
      ),
      instanceName: LocatorInstanceNameConstants.boltzSwapWatcherInstanceName,
    );

    locator.registerLazySingleton<SwapWatcherService>(
      () => SwapWatcherService(
        boltzRepo: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants
                  .boltzTestnetSwapRepositoryInstanceName,
        ),
        walletAddressRepository: locator<WalletAddressRepository>(),
        settingsRepository: locator<SettingsRepository>(),
        feesRepository: locator<FeesRepository>(),
      ),
      instanceName:
          LocatorInstanceNameConstants.boltzTestnetSwapWatcherInstanceName,
    );
  }

  static void registerUsecases() {
    locator.registerFactory<DecodeInvoiceUsecase>(
      () => DecodeInvoiceUsecase(
        mainnetBoltzSwapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        testnetBoltzSwapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants
                  .boltzTestnetSwapRepositoryInstanceName,
        ),
      ),
    );

    locator.registerFactory<GetSwapLimitsUsecase>(
      () => GetSwapLimitsUsecase(
        mainnetBoltzSwapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        testnetBoltzSwapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants
                  .boltzTestnetSwapRepositoryInstanceName,
        ),
      ),
    );

    locator.registerFactory<RestartSwapWatcherUsecase>(
      () => RestartSwapWatcherUsecase(
        swapWatcherService: locator<SwapWatcherService>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapWatcherInstanceName,
        ),
      ),
    );

    locator.registerFactory<GetSwapUsecase>(
      () => GetSwapUsecase(
        mainnetBoltzSwapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        testnetBoltzSwapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants
                  .boltzTestnetSwapRepositoryInstanceName,
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<GetSwapsUsecase>(
      () => GetSwapsUsecase(
        mainnetBoltzSwapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        testnetBoltzSwapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants
                  .boltzTestnetSwapRepositoryInstanceName,
        ),
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
    locator.registerFactory<UpdatePaidChainSwapUsecase>(
      () => UpdatePaidChainSwapUsecase(
        swapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        swapRepositoryTestnet: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants
                  .boltzTestnetSwapRepositoryInstanceName,
        ),
      ),
    );
    locator.registerFactory<GetAutoSwapSettingsUsecase>(
      () => GetAutoSwapSettingsUsecase(
        mainnetRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        testnetRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants
                  .boltzTestnetSwapRepositoryInstanceName,
        ),
      ),
    );
    locator.registerFactory<SaveAutoSwapSettingsUsecase>(
      () => SaveAutoSwapSettingsUsecase(
        mainnetRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        testnetRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants
                  .boltzTestnetSwapRepositoryInstanceName,
        ),
      ),
    );
    locator.registerFactory<AutoSwapExecutionUsecase>(
      () => AutoSwapExecutionUsecase(
        mainnetRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        testnetRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants
                  .boltzTestnetSwapRepositoryInstanceName,
        ),
        walletRepository: locator<WalletRepository>(),
        liquidWalletRepository: locator<LiquidWalletRepository>(),
        liquidBlockchainRepository: locator<LiquidBlockchainRepository>(),
        seedRepository: locator<SeedRepository>(),
        walletTxRepository: locator<WalletTransactionRepository>(),
        labelRepository: locator<LabelRepository>(),
      ),
    );
    locator.registerFactory<CreateChainSwapUsecase>(
      () => CreateChainSwapUsecase(
        walletRepository: locator<WalletRepository>(),
        seedRepository: locator<SeedRepository>(),
        swapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        swapRepositoryTestnet: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants
                  .boltzTestnetSwapRepositoryInstanceName,
        ),
      ),
    );
    locator.registerFactory<CreateChainSwapToExternalUsecase>(
      () => CreateChainSwapToExternalUsecase(
        walletRepository: locator<WalletRepository>(),
        seedRepository: locator<SeedRepository>(),
        swapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        swapRepositoryTestnet: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants
                  .boltzTestnetSwapRepositoryInstanceName,
        ),
      ),
    );
    locator.registerFactory<ProcessSwapUsecase>(
      () => ProcessSwapUsecase(
        watcherService: locator<SwapWatcherService>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapWatcherInstanceName,
        ),
      ),
    );
  }
}
