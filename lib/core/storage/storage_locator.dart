import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/impl/secure_storage_data_source_impl.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/storage/migrations/004_legacy/migrate_v4_legacy_usecase.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/migrate_v5_hive_to_sqlite_usecase.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_hive_datasource.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_seed_repository.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_wallet_repository.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/secure_storage_datasource.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository_impl.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageLocator {
  static Future<void> registerDatasources() async {
    locator.registerLazySingleton<KeyValueStorageDatasource<String>>(
      () => SecureStorageDatasourceImpl(const FlutterSecureStorage()),
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
        mainnetSwapRepository:
            locator<SwapRepository>(
                  instanceName:
                      LocatorInstanceNameConstants
                          .boltzSwapRepositoryInstanceName,
                )
                as BoltzSwapRepositoryImpl,
        logger: locator<Logger>(),
      ),
    );
    locator.registerFactory<MigrateToV4LegacyUsecase>(
      () => MigrateToV4LegacyUsecase(MigrationSecureStorageDatasource()),
    );
  }
}
