import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_storage_keys.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/secure_storage_datasource.dart';

Future<void> doMigration0_3to0_4() async {
  final secureStorageDatasource = MigrationSecureStorageDatasource();

  await secureStorageDatasource.store(
    key: OldStorageKeys.version.name,
    value: '0.4.0',
  );
}
