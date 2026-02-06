import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_all_seeds_usecase.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/impl/secure_storage_data_source_impl.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/storage/migrations/004_legacy/migrate_v4_legacy_usecase.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/get_old_seeds_usecase.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/migrate_v5_hive_to_sqlite_usecase.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_hive_datasource.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_seed_repository.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_wallet_repository.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/secure_storage_datasource.dart';
import 'package:bb_mobile/core/storage/requires_migration_usecase.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_v9/flutter_secure_storage_v9.dart'
    as fss_v9;
import 'package:get_it/get_it.dart';

class StorageLocator {
  static Future<void> registerDatasources(GetIt locator) async {
    const secureStorage = FlutterSecureStorage(
      aOptions: AndroidOptions(
        resetOnError: false,
        // CRITICAL: Never auto-delete wallet seeds!
        // In flutter_secure_storage v10+, resetOnError defaults to TRUE.
        // Setting true will delete secure storage contents on errors!!
        // We must set it to false and handle errors manually.
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
        // This will ensure that secure storage can be used by background tasks while the phone is locked.
      ),
    );
    const secureStorageV9 = fss_v9.FlutterSecureStorageV9(
      aOptions: fss_v9.AndroidOptions(
        encryptedSharedPreferences: true,
        sharedPreferencesName: 'FlutterSecureStorage',
      ),
      iOptions: fss_v9.IOSOptions(
        accessibility: fss_v9.KeychainAccessibility.first_unlock_this_device,
        // This will ensure that secure storage can be used by background tasks while the phone is locked.
      ),
    );

    locator.registerLazySingleton<KeyValueStorageDatasource<String>>(
      () => SecureStorageDatasourceImpl(
        secureStorage,
        storageV9: secureStorageV9,
      ),
      instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
    );
    locator.registerLazySingleton<MigrationSecureStorageDatasource>(
      () => MigrationSecureStorageDatasource(
        secureStorage,
        storageV9: secureStorageV9,
      ),
    );
    final oldHiveBox = await OldHiveDatasource.getBox(secureStorage);
    locator.registerLazySingleton<OldHiveDatasource>(
      () => OldHiveDatasource(oldHiveBox),
    );
  }

  static void registerRepositories(GetIt locator) {
    locator.registerLazySingleton<OldSeedRepository>(
      () => OldSeedRepository(locator<MigrationSecureStorageDatasource>()),
    );
    locator.registerLazySingleton<OldWalletRepository>(
      () => OldWalletRepository(locator<OldHiveDatasource>()),
    );
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<MigrateToV5HiveToSqliteToUsecase>(
      () => MigrateToV5HiveToSqliteToUsecase(
        newSeedRepository: locator<SeedRepository>(),
        oldSeedRepository: locator<OldSeedRepository>(),
        oldWalletRepository: locator<OldWalletRepository>(),
        newWalletRepository: locator<WalletRepository>(),
        secureStorage: locator<MigrationSecureStorageDatasource>(),
        mainnetBoltzSwapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
      ),
    );
    locator.registerFactory<GetOldSeedsUsecase>(
      () => GetOldSeedsUsecase(
        oldSeedRepository: locator<OldSeedRepository>(),
        oldWalletRepository: locator<OldWalletRepository>(),
      ),
    );
    locator.registerFactory<GetAllSeedsUsecase>(
      () => GetAllSeedsUsecase(seedRepository: locator<SeedRepository>()),
    );
    locator.registerFactory<MigrateToV4LegacyUsecase>(
      () =>
          MigrateToV4LegacyUsecase(locator<MigrationSecureStorageDatasource>()),
    );
    locator.registerFactory<RequiresMigrationUsecase>(
      () => RequiresMigrationUsecase(
        locator<MigrationSecureStorageDatasource>(),
        locator<WalletRepository>(),
      ),
    );
  }
}
