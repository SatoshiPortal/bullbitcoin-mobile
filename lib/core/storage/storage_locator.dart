import 'dart:io';

import 'package:bb_mobile/core/seed/data/datasources/seed_store_type_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_store_type_model.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed_store_type.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_all_seeds_usecase.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/impl/secure_storage_data_source_impl.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/impl/secure_storage_legacy_datasource_impl.dart';
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
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
        // No flag — fresh install, 6.5.2 user, or first run of 6.10.0.
        // Try FSS10 first with migrateOnAlgorithmChange:false. A 6.5.2 user
        // with ESP data will hit the explicit error branch in
        // FlutterSecureStorage.java that throws "EncryptedSharedPreferences
        // data found but migration is disabled" — caught here and routed to
        // FSS9 which can still read ESP data via encryptedSharedPreferences:true.
        log.fine('StorageLocator: no existing flag — attempting fss10 init');
        try {
          final storage = fss10.FlutterSecureStorage(
            aOptions: const fss10.AndroidOptions(
              // Never auto-delete data on errors. v10 default is true.
              resetOnError: false,
              // Do not run any algorithm migration. Combined with the default
              // encryptedSharedPreferences:false, devices that still have
              // 6.5.2 ESP data on disk will throw on first read — which we
              // catch and fall back to FSS9 below. Devices already on FSS10
              // custom-cipher (cohort A) and fresh installs are unaffected.
              migrateOnAlgorithmChange: false,
            ),
            iOptions: const fss10.IOSOptions(
              accessibility:
                  fss10.KeychainAccessibility.first_unlock_this_device,
            ),
          );
          // Trigger native init by reading. The constructor alone never
          // throws — failures only surface on data access.
          final data = await storage.readAll();
          log.fine(
            'StorageLocator: fss10 readAll returned ${data.length} entries',
          );

          // Belt-and-suspenders: if FSS10 returns empty but the SQLite DB
          // from a prior install exists, treat it as a silent failure and
          // route to FSS9.
          if (data.isEmpty) {
            final docsDir = await getApplicationDocumentsDirectory();
            final dbFile = File(
              p.join(docsDir.path, 'bullbitcoin_sqlite.sqlite'),
            );
            if (await dbFile.exists()) {
              log.warning(
                'StorageLocator: fss10 readAll returned empty but database '
                'exists — silent failure detected, falling back to fss9',
              );
              throw Exception(
                'FSS10 silent failure: prior install data exists '
                'but readAll returned 0 entries',
              );
            }
            log.fine(
              'StorageLocator: readAll empty + no database = fresh install',
            );
          }

          secureStorageDatasource = SecureStorageDatasourceImpl(storage);
          // Only commit the flag AFTER readAll confirms FSS10 works.
          await seedStoreTypeDatasource.write(
            SeedStoreTypeModel.fromEntity(
              const SeedStoreType(storageLibrary: SeedStorageLibrary.fss10),
            ),
          );
          log.fine('StorageLocator: fss10 verified and flag written');
        } catch (fss10Error) {
          log.warning(
            'StorageLocator: fss10 readAll failed — falling back to fss9. '
            'Error: ${fss10Error.runtimeType}: $fss10Error',
            error: fss10Error,
          );

          try {
            final storage = fss9.FlutterSecureStorage(
              aOptions: const fss9.AndroidOptions(
                resetOnError: false,
                // ESP path used by 6.5.2 — same MasterKey alias and Tink
                // scheme, so existing data decrypts cleanly.
                encryptedSharedPreferences: true,
              ),
              iOptions: const fss9.IOSOptions(
                accessibility:
                    fss9.KeychainAccessibility.first_unlock_this_device,
              ),
            );
            final data = await storage.readAll();
            log.fine(
              'StorageLocator: fss9 readAll returned ${data.length} entries',
            );
            secureStorageDatasource = SecureStorageLegacyDatasourceImpl(
              storage,
            );
            await seedStoreTypeDatasource.write(
              SeedStoreTypeModel.fromEntity(
                const SeedStoreType(storageLibrary: SeedStorageLibrary.fss9),
              ),
            );
            log.fine('StorageLocator: fss9 fallback verified and flag written');
          } catch (fss9Error) {
            log.shout(
              message:
                  'StorageLocator: both fss10 and fss9 failed. '
                  'fss10: ${fss10Error.runtimeType}, '
                  'fss9: ${fss9Error.runtimeType}',
              error: fss9Error,
              trace: StackTrace.current,
            );
            rethrow;
          }
        }

      case SeedStorageLibrary.fss9:
        // Previous session committed to FSS9 (6.5.2 ESP user). Stay on FSS9
        // with the same options that succeeded then. The app shows a
        // LegacyStorageWarningOverlay prompting backup + reinstall.
        log.fine(
          'StorageLocator: existing flag is fss9 — using legacy storage',
        );
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
        log.fine('StorageLocator: fss9 legacy storage initialized from flag');

      case SeedStorageLibrary.fss10:
        // Previous session committed to FSS10 (cohort A or fresh install).
        log.fine(
          'StorageLocator: existing flag is fss10 — using current storage',
        );
        final storage = fss10.FlutterSecureStorage(
          aOptions: const fss10.AndroidOptions(
            resetOnError: false,
            migrateOnAlgorithmChange: false,
          ),
          iOptions: const fss10.IOSOptions(
            accessibility: fss10.KeychainAccessibility.first_unlock_this_device,
          ),
        );
        secureStorageDatasource = SecureStorageDatasourceImpl(storage);
        log.fine('StorageLocator: fss10 storage initialized from flag');
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
