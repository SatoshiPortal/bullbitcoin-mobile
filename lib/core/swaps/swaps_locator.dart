import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/swaps/data/datasources/boltz_datasource.dart';
import 'package:bb_mobile/core/swaps/data/datasources/boltz_storage_datasource.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/auto_swap_settings_repository.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/delete_swap_master_key_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/disable_autoswap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/disable_autoswap_warning_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/ensure_swap_master_key_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_master_key_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swaps_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/save_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:get_it/get_it.dart';

class SwapsLocator {
  static Future<void> registerDatasources(GetIt locator) async {
    locator.registerLazySingleton<BoltzStorageDatasource>(
      () => BoltzStorageDatasource(
        secureSwapStorage: locator<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
        localSwapStorage: locator<SqliteDatabase>(),
      ),
    );
  }

  static void registerRepositories(GetIt locator) {
    locator.registerLazySingleton<BoltzSwapRepository>(
      () => BoltzSwapRepository(
        boltz: BoltzDatasource(boltzStore: locator<BoltzStorageDatasource>()),
        isTestnet: false,
      ),
      instanceName:
          LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
    );
    locator.registerLazySingleton<AutoSwapSettingsRepository>(
      () => locator<BoltzSwapRepository>(
        instanceName:
            LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
      ),
    );
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<GetSwapMasterKeyUsecase>(
      () => GetSwapMasterKeyUsecase(
        settingsRepository: locator<SettingsRepository>(),
        walletRepository: locator<WalletRepository>(),
        swapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
      ),
    );

    locator.registerFactory<DeleteSwapMasterKeyUsecase>(
      () => DeleteSwapMasterKeyUsecase(
        settingsRepository: locator<SettingsRepository>(),
        walletRepository: locator<WalletRepository>(),
        swapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
      ),
    );

    locator.registerFactory<GetSwapUsecase>(
      () => GetSwapUsecase(
        boltzSwapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
      ),
    );

    locator.registerFactory<GetSwapsUsecase>(
      () => GetSwapsUsecase(
        boltzSwapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
      ),
    );

    locator.registerFactory<WatchSwapUsecase>(
      () => WatchSwapUsecase(
        swapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
      ),
    );

    locator.registerFactory<GetAutoSwapSettingsUsecase>(
      () => GetAutoSwapSettingsUsecase(
        repository: locator<AutoSwapSettingsRepository>(),
      ),
    );
    locator.registerFactory<SaveAutoSwapSettingsUsecase>(
      () => SaveAutoSwapSettingsUsecase(
        repository: locator<AutoSwapSettingsRepository>(),
      ),
    );
    locator.registerFactory<WatchAutoSwapSettingsUsecase>(
      () => WatchAutoSwapSettingsUsecase(
        repository: locator<AutoSwapSettingsRepository>(),
      ),
    );
    locator.registerFactory<DisableAutoswapWarningUsecase>(
      () => DisableAutoswapWarningUsecase(
        repository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
      ),
    );
    locator.registerFactory<DisableAutoswapUsecase>(
      () => DisableAutoswapUsecase(
        repository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
      ),
    );
    locator.registerFactory<EnsureSwapMasterKeyUsecase>(
      () => EnsureSwapMasterKeyUsecase(
        settingsRepository: locator<SettingsRepository>(),
        walletRepository: locator<WalletRepository>(),
        seedRepository: locator<SeedRepository>(),
        swapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
      ),
    );
  }
}
