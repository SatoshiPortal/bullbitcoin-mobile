import 'package:bb_mobile/core/storage/migrations/004_legacy/legacy_migration.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_storage_keys.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/secure_storage_datasource.dart';
import 'package:flutter/foundation.dart';

class MigrateToV4LegacyUsecase {
  final MigrationSecureStorageDatasource _secureStorageDatasource;
  MigrateToV4LegacyUsecase(this._secureStorageDatasource);

  Future<bool> execute() async {
    try {
      final fromVersion = await _secureStorageDatasource.fetch(
        key: OldStorageKeys.version.name,
      );
      if (fromVersion == null) {
        return false;
      }
      final isV4 = await legacyMigrateToV4(fromVersion);
      return isV4;
    } catch (e) {
      debugPrint('legacy migration failed: $e');
      return false;
    }
  }
}
