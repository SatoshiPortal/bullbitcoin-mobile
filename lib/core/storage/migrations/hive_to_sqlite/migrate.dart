import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/migrate_hive_to_sqlite_usecase.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/migration_secure_storage_datasource.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/new_seed_repository.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_hive_datasource.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_seed_repository.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_wallet_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:flutter/foundation.dart';

extension MigrateHiveToSqlite on SqliteDatabase {
  Future<bool> migrateFromHiveToSqlite() async {
    try {
      final migrationSecureStorage = MigrationSecureStorageDatasource();
      final oldHiveDatasource = await OldHiveDatasource.init();

      final oldSeedRepository = OldSeedRepository(migrationSecureStorage);
      final newSeedRepository = NewSeedRepository(migrationSecureStorage);

      final oldWalletRepository = OldWalletRepository(oldHiveDatasource);

      final usecase = MigrateHiveToSqliteUsecase(
        sqliteDatabase: this,
        newSeedRepository: newSeedRepository,
        oldSeedRepository: oldSeedRepository,
        oldWalletRepository: oldWalletRepository,
      );

      return await usecase.execute();
    } catch (e) {
      debugPrint('migration failed: $e');
      return false;
    }
  }
}
