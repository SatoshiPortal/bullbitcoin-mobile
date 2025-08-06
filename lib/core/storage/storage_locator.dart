import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
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
import 'package:bb_mobile/core/storage/secure_storage.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/locator.dart';

class StorageLocator {
  static Future<void> registerDatasources() async {
    locator.registerLazySingleton<KeyValueStorageDatasource<String>>(
      () => SecureStorageDatasourceImpl(SecureStorage.init()),
      instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
    );
    locator.registerLazySingleton<MigrationSecureStorageDatasource>(
      () => MigrationSecureStorageDatasource(),
    );
    final oldHiveBox = await OldHiveDatasource.getBox();
    locator.registerLazySingleton<OldHiveDatasource>(
      () => OldHiveDatasource(oldHiveBox),
    );
  }

  static void registerRepositories() {
    locator.registerLazySingleton<OldSeedRepository>(
      () => OldSeedRepository(locator<MigrationSecureStorageDatasource>()),
    );
    locator.registerLazySingleton<OldWalletRepository>(
      () => OldWalletRepository(locator<OldHiveDatasource>()),
    );
  }

  static void registerUsecases() {
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
    locator.registerFactory<MigrateToV4LegacyUsecase>(
      () => MigrateToV4LegacyUsecase(MigrationSecureStorageDatasource()),
    );
    locator.registerFactory<RequiresMigrationUsecase>(
      () => RequiresMigrationUsecase(
        locator<MigrationSecureStorageDatasource>(),
        locator<WalletRepository>(),
      ),
    );
  }
}
