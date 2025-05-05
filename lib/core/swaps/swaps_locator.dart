import 'package:bb_mobile/core/fees/data/fees_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/impl/hive_storage_datasource_impl.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/swaps/data/datasources/boltz_datasource.dart';
import 'package:bb_mobile/core/swaps/data/datasources/boltz_storage_datasource.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository_impl.dart';
import 'package:bb_mobile/core/swaps/data/services/swap_watcher_impl.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/services/swap_watcher_service.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/decode_invoice_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_limits_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/restart_swap_watcher_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/locator.dart';
import 'package:hive/hive.dart';

class SwapsLocator {
  static Future<void> registerDatasources() async {
    final boltzSwapsBox = await Hive.openBox<String>(
      HiveBoxNameConstants.boltzSwaps,
    );
    locator.registerLazySingleton<KeyValueStorageDatasource<String>>(
      () => HiveStorageDatasourceImpl<String>(boltzSwapsBox),
      instanceName:
          LocatorInstanceNameConstants
              .boltzSwapsHiveStorageDatasourceInstanceName,
    );

    locator.registerLazySingleton<BoltzStorageDatasource>(
      () => BoltzStorageDatasource(
        secureSwapStorage: locator<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
        localSwapStorage: locator<KeyValueStorageDatasource<String>>(
          instanceName:
              LocatorInstanceNameConstants
                  .boltzSwapsHiveStorageDatasourceInstanceName,
        ),
      ),
    );
  }

  static void registerRepositories() {
    locator.registerLazySingleton<SwapRepository>(
      () => BoltzSwapRepositoryImpl(
        boltz: BoltzDatasource(
          url: ApiServiceConstants.boltzTestnetUrlPath,
          boltzStore: locator<BoltzStorageDatasource>(),
        ),
      ),
      instanceName:
          LocatorInstanceNameConstants.boltzTestnetSwapRepositoryInstanceName,
    );

    locator.registerLazySingleton<SwapRepository>(
      () => BoltzSwapRepositoryImpl(
        boltz: BoltzDatasource(boltzStore: locator<BoltzStorageDatasource>()),
      ),
      instanceName:
          LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
    );
  }

  static void registerServices() {
    // add swap watcher service
    locator.registerLazySingleton<SwapWatcherService>(
      () => SwapWatcherServiceImpl(
        boltzRepo:
            locator<SwapRepository>(
                  instanceName:
                      LocatorInstanceNameConstants
                          .boltzSwapRepositoryInstanceName,
                )
                as BoltzSwapRepositoryImpl,
        walletAddressRepository: locator<WalletAddressRepository>(),
        settingsRepository: locator<SettingsRepository>(),
        feesRepository: locator<FeesRepository>(),
      ),
      instanceName: LocatorInstanceNameConstants.boltzSwapWatcherInstanceName,
    );

    // add swap watcher service
    locator.registerLazySingleton<SwapWatcherService>(
      () => SwapWatcherServiceImpl(
        boltzRepo:
            locator<SwapRepository>(
                  instanceName:
                      LocatorInstanceNameConstants
                          .boltzTestnetSwapRepositoryInstanceName,
                )
                as BoltzSwapRepositoryImpl,
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
        mainnetSwapRepository: locator<SwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        testnetSwapRepository: locator<SwapRepository>(
          instanceName:
              LocatorInstanceNameConstants
                  .boltzTestnetSwapRepositoryInstanceName,
        ),
      ),
    );

    locator.registerFactory<GetSwapLimitsUsecase>(
      () => GetSwapLimitsUsecase(
        mainnetSwapRepository: locator<SwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        testnetSwapRepository: locator<SwapRepository>(
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
        mainnetSwapRepository: locator<SwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        testnetSwapRepository: locator<SwapRepository>(
          instanceName:
              LocatorInstanceNameConstants
                  .boltzTestnetSwapRepositoryInstanceName,
        ),
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
