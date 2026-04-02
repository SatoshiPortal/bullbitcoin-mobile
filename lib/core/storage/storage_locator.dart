import 'package:bb_mobile/core/seed/data/datasources/seed_store_type_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_store_type_model.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed_store_type.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_all_seeds_usecase.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/impl/secure_storage_data_source_impl.dart';import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/impl/secure_storage_legacy_datasource_impl.dart';
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
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as fss10;
import 'package:flutter_secure_storage_legacy/flutter_secure_storage.dart'
    as fss9;
import 'package:get_it/get_it.dart';

class StorageLocator {
  static Future<void> registerDatasources(GetIt locator) async {

    const seedStoreTypeDatasource = SeedStoreTypeDatasource();
    locator.registerLazySingleton<SeedStoreTypeDatasource>(
      () => seedStoreTypeDatasource,
    );

    final seedStoreModel = await seedStoreTypeDatasource.read();
    final existingLibrary = seedStoreModel?.toEntity().storageLibrary;

    log.info('SeedStoreType flag on startup: $existingLibrary');

    late final KeyValueStorageDatasource<String> secureStorageDatasource;

    switch (existingLibrary) {
      case null:
        // No flag — fresh install or first run of 6.9.0.
        // Always try the latest storage options first and fallback to older options
        try {
          final storage = fss10.FlutterSecureStorage(
            aOptions: const fss10.AndroidOptions(
              resetOnError: false,
              migrateWithBackup: true,
            ),
            iOptions: const fss10.IOSOptions(
              accessibility:
                  fss10.KeychainAccessibility.first_unlock_this_device,
            ),
          );
          secureStorageDatasource = SecureStorageDatasourceImpl(storage);
          await seedStoreTypeDatasource.write(
            SeedStoreTypeModel.fromEntity(
              const SeedStoreType(storageLibrary: SeedStorageLibrary.fss10),
            ),
          );
          log.info(
            'StorageLocator: fss10 initialized successfully, flag written',
          );
        } catch (fss10Error) {
          log.warning(
            'StorageLocator: fss10 init failed, falling back to fss9',
            error: fss10Error,
          );

          final storage = fss9.FlutterSecureStorage(
            aOptions: const fss9.AndroidOptions(
              resetOnError: false,
              encryptedSharedPreferences: true,
            ),
            iOptions: const fss9.IOSOptions(
              accessibility:
                  fss9.KeychainAccessibility.first_unlock_this_device,
            ),
          );
          secureStorageDatasource = SecureStorageLegacyDatasourceImpl(storage);
          await seedStoreTypeDatasource.write(
            SeedStoreTypeModel.fromEntity(
              const SeedStoreType(storageLibrary: SeedStorageLibrary.fss9),
            ),
          );
          log.info(
            'StorageLocator: fss9 initialized successfully, flag written',
          );
        }

      case SeedStorageLibrary.fss9:
        final storage = fss9.FlutterSecureStorage(
          aOptions: const fss9.AndroidOptions(
            resetOnError: false,
            encryptedSharedPreferences: true,
          ),
          iOptions: const fss9.IOSOptions(
            accessibility: fss9.KeychainAccessibility.first_unlock_this_device,
          ),
        );
        secureStorageDatasource = SecureStorageLegacyDatasourceImpl(storage);

      case SeedStorageLibrary.fss10:
        final storage = fss10.FlutterSecureStorage(
          aOptions: const fss10.AndroidOptions(
            resetOnError: false,
            migrateWithBackup: true,
          ),
          iOptions: const fss10.IOSOptions(
            accessibility: fss10.KeychainAccessibility.first_unlock_this_device,
          ),
        );
        secureStorageDatasource = SecureStorageDatasourceImpl(storage);
    }

    locator.registerLazySingleton<KeyValueStorageDatasource<String>>(
      () => secureStorageDatasource,
      instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
    );

    locator.registerLazySingleton<MigrationSecureStorageDatasource>(
      () => MigrationSecureStorageDatasource(secureStorageDatasource),
    );
    final oldHiveBox = await OldHiveDatasource.getBox(secureStorageDatasource);
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
