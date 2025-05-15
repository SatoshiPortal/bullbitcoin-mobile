import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/impl/secure_storage_data_source_impl.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/storage/migrations/004_legacy/migrate_v4_legacy_usecase.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/migrate_v5_hive_to_sqlite_usecase.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/datasource/new_wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/new_seed_repository.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/wallet_repository.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_hive_datasource.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_seed_repository.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_wallet_repository.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/secure_storage_datasource.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/constants.dart';
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
    locator.registerLazySingleton<NewWalletMetadataDatasource>(
      () => NewWalletMetadataDatasource(
        sqliteDatasource: locator<SqliteDatabase>(),
      ),
    );
  }

  static void registerRepositories() {
    locator.registerLazySingleton<NewSeedRepository>(
      () => NewSeedRepository(locator<MigrationSecureStorageDatasource>()),
    );
    locator.registerLazySingleton<OldSeedRepository>(
      () => OldSeedRepository(locator<MigrationSecureStorageDatasource>()),
    );
    locator.registerLazySingleton<OldWalletRepository>(
      () => OldWalletRepository(locator<OldHiveDatasource>()),
    );
    locator.registerLazySingleton<NewWalletRepository>(
      () => NewWalletRepository(
        walletMetadataDatasource: locator<NewWalletMetadataDatasource>(),
      ),
    );
  }

  static void registerUsecases() {
    locator.registerFactory<MigrateSeedToV5AndGetHiveToSqliteWalletsUsecase>(
      () => MigrateSeedToV5AndGetHiveToSqliteWalletsUsecase(
        newSeedRepository: locator<NewSeedRepository>(),
        oldSeedRepository: locator<OldSeedRepository>(),
        oldWalletRepository: locator<OldWalletRepository>(),
      ),
    );
    locator.registerFactory<MigrateToV4LegacyUsecase>(
      () => MigrateToV4LegacyUsecase(MigrationSecureStorageDatasource()),
    );
  }
}
