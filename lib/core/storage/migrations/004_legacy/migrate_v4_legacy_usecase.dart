import 'package:bb_mobile/core/storage/migrations/004_legacy/legacy_migration.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_storage_keys.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/secure_storage_datasource.dart';
import 'package:flutter/foundation.dart';

class MigrateToV4LegacyUsecase {
  final MigrationSecureStorageDatasource _secureStorageDatasource;
  MigrateToV4LegacyUsecase(this._secureStorageDatasource);

  Future<bool> execute() async {
    try {
      final version = await _secureStorageDatasource.fetch(
        key: OldStorageKeys.version.name,
      );
      if (version == null) {
        return false;
      }
      await legacyMigrateToV4(version, '0.4');
      debugPrint('legacy migration executed');
      return true;
    } catch (e) {
      debugPrint('legacy migration failed: $e');
      return false;
    }
  }
}
