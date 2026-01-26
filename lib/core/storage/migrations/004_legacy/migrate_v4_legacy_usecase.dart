import 'package:bb_mobile/core/storage/migrations/004_legacy/legacy_migration.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_storage_keys.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/secure_storage_datasource.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class MigrateToV4LegacyUsecase {
  final MigrationSecureStorageDatasource _migrationSecureStorageDatasource;
  MigrateToV4LegacyUsecase(this._migrationSecureStorageDatasource);

  Future<bool> execute() async {
    try {
      final fromVersion = await _migrationSecureStorageDatasource.fetch(
        key: OldStorageKeys.version.name,
      );
      if (fromVersion == null) {
        return false;
      }
      final isV4 = await legacyMigrateToV4(fromVersion);
      return isV4;
    } catch (e) {
      log.severe('legacy migration failed: $e', trace: StackTrace.current);
      return false;
    }
  }
}
