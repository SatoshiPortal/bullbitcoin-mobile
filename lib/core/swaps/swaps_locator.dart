import 'package:bb_mobile/core/address/domain/repositories/address_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/swaps/data/datasources/boltz_datasource.dart';
import 'package:bb_mobile/core/swaps/data/datasources/boltz_storage_datasource.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository_impl.dart';
import 'package:bb_mobile/core/swaps/data/services/swap_watcher_impl.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/services/swap_watcher_service.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_limits_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/restart_swap_watcher_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/locator.dart';

class SwapsLocator {
  static void registerRepositories() {
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
  }

  static void registerServices() {
    // add swap watcher service
    locator.registerLazySingleton<SwapWatcherService>(
      () => SwapWatcherServiceImpl(
        boltzRepo: locator<SwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ) as BoltzSwapRepositoryImpl,
        addressRepository: locator<AddressRepository>(),
      ),
      instanceName: LocatorInstanceNameConstants.boltzSwapWatcherInstanceName,
    );

    // add swap watcher service
    locator.registerLazySingleton<SwapWatcherService>(
      () => SwapWatcherServiceImpl(
        boltzRepo: locator<SwapRepository>(
          instanceName: LocatorInstanceNameConstants
              .boltzTestnetSwapRepositoryInstanceName,
        ) as BoltzSwapRepositoryImpl,
        addressRepository: locator<AddressRepository>(),
      ),
      instanceName:
          LocatorInstanceNameConstants.boltzTestnetSwapWatcherInstanceName,
    );
  }

  static void registerUsecases() {
    // Register GetSwapLimitsUsecase with mainnet and testnet repositories
    locator.registerFactory<GetSwapLimitsUsecase>(
      () => GetSwapLimitsUsecase(
        mainnetSwapRepository: locator<SwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        testnetSwapRepository: locator<SwapRepository>(
          instanceName: LocatorInstanceNameConstants
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
