import 'dart:convert';
import 'dart:io';

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
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_v9/flutter_secure_storage_v9.dart'
    as fss_v9;
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';

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

    // Attempt one-time migration from v9 to v10 at startup
    await _tryMigrateFromV9ToV10(secureStorageV9, secureStorage);

    locator.registerLazySingleton<KeyValueStorageDatasource<String>>(
      () => SecureStorageDatasourceImpl(secureStorage),
      instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
    );
    locator.registerLazySingleton<MigrationSecureStorageDatasource>(
      () => MigrationSecureStorageDatasource(secureStorage),
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

  static Future<void> _tryMigrateFromV9ToV10(
    fss_v9.FlutterSecureStorageV9 storageV9,
    FlutterSecureStorage storage,
  ) async {
    try {
      // First, check if v10 storage is working
      await storage.readAll();
      log.fine('v10 storage is working, no migration needed');
      return;
    } catch (e) {
      log.fine('v10 storage failed, attempting migration from v9');
    }

    try {
      // Read all values from v9 storage
      final valuesV9 = await storageV9.readAll();
      if (valuesV9.isEmpty) {
        log.fine('No v9 storage to migrate');
        return;
      }

      // Backup v9 storage before migration
      await _dumpV9StorageToFile(valuesV9);

      /* Until we know we get the data, we can't risk wiping v10 storage.
      // So the migration is disabled for now.
      try {
        await storage.write(
          key: valuesV9.entries.first.key,
          value: valuesV9.entries.first.value,
          aOptions: AndroidOptions(resetOnError: true),
        );
      } catch (e) {
        // This write is just to reset the v10 storage on error
        log.info(
          'Failed first write to v10 storage, attempting reset before migration',
          error: e,
          trace: StackTrace.current,
        );
      }

      // Now that it's reset, we can migrate all values to v10 storage
      for (final entry in valuesV9.entries) {
        await storage.write(key: entry.key, value: entry.value);
      }

      log.fine('Successfully migrated ${valuesV9.length} items from v9 to v10');*/
    } catch (e) {
      log.severe(
        message: 'Failed to migrate from v9 to v10',
        error: e,
        trace: StackTrace.current,
      );
    }
  }

  static Future<void> _dumpV9StorageToFile(Map<String, String> values) async {
    try {
      Directory? dir;
      if (Platform.isAndroid) {
        // Use external storage on Android so users can access the backup
        dir = await getDownloadsDirectory();
        if (dir == null) {
          log.severe(
            message: 'Could not get Download directory for backup',
            trace: StackTrace.current,
            error: Exception('No directory'),
          );
          dir = await getExternalStorageDirectory();
        }
      } else {
        // Use documents directory on iOS (accessible via Files app if enabled)
        dir = await getApplicationDocumentsDirectory();
      }

      if (dir == null) {
        log.severe(
          message: 'Could not get storage directory for backup',
          trace: StackTrace.current,
          error: Exception('No directory'),
        );
        return;
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final file = File('${dir.path}/secure_storage_v9_backup_$timestamp.json');

      final backup = {'timestamp': timestamp, 'values': values};

      await file.writeAsString(json.encode(backup));
      log.fine('Backed up v9 storage to ${file.path}');
    } catch (e) {
      log.severe(
        message: 'Failed to backup v9 storage',
        error: e,
        trace: StackTrace.current,
      );
    }
  }
}
