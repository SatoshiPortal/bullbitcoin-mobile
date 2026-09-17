import 'dart:io';

import 'package:bb_mobile/core/seed/data/datasources/seed_store_type_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_store_type_model.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed_store_type.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_all_seeds_usecase.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/impl/secure_storage_data_source_impl.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/impl/secure_storage_legacy_datasource_impl.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as fss10;
import 'package:flutter_secure_storage_legacy/flutter_secure_storage.dart'
    as fss9;
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StorageLocator {
  static const _prewarmKey = '__bull_secure_storage_prewarm__';
  static const _fss10Storage = fss10.FlutterSecureStorage(
    aOptions: fss10.AndroidOptions(
      resetOnError: false,
      migrateOnAlgorithmChange: false,
    ),
    iOptions: fss10.IOSOptions(
      accessibility: fss10.KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Starts Android's FSS10 cipher initialization on a fresh-looking install.
  ///
  /// The native plugin may inspect legacy ESP while initializing, so the
  /// optimization is skipped if any supported prior-install marker exists.
  /// The manifest disables Android backup; classification still fails closed.
  /// The authoritative startup probe handles FSS9 fallback and reports errors.
  static Future<void> prewarmSecureStorage() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    try {
      const seedStoreTypeDatasource = SeedStoreTypeDatasource();
      if (await seedStoreTypeDatasource.read() != null) return;

      final priorInstall = await _inspectPriorInstallData();
      if (priorInstall.hasDatabase || priorInstall.hasLegacyHiveBoxes) return;

      await _fss10Storage.containsKey(key: _prewarmKey);
    } catch (_) {
      // Fail closed. The startup probe repeats initialization and remains the
      // only path allowed to select FSS10 or route an install through FSS9.
    }
  }

  static Future<({bool hasDatabase, bool hasLegacyHiveBoxes})>
  _inspectPriorInstallData() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final database = File(
      p.join(documentsDirectory.path, 'bullbitcoin_sqlite.sqlite'),
    );
    final hasDatabase = await database.exists();
    final hasLegacyHiveBoxes = await documentsDirectory.list().any(
      (entity) => entity.path.endsWith('.hive'),
    );

    return (hasDatabase: hasDatabase, hasLegacyHiveBoxes: hasLegacyHiveBoxes);
  }

  static Future<void> registerDatasources(GetIt locator) async {
    const seedStoreTypeDatasource = SeedStoreTypeDatasource();
    locator.registerLazySingleton<SeedStoreTypeDatasource>(
      () => seedStoreTypeDatasource,
    );

    final seedStoreModel = await seedStoreTypeDatasource.read();
    final existingLibrary = seedStoreModel?.toEntity().storageLibrary;

    log.info('SeedStoreType flag on startup: $existingLibrary');

    late final KeyValueStorageDatasource<String> secureStorageDatasource;

    if (Platform.isAndroid) {
      // The FSS9/FSS10 hybrid fallback chain below exists solely to
      // recover 6.5.2 Android users whose wallet data lives in Jetpack
      // Security's EncryptedSharedPreferences (ESP, Tink-backed). ESP
      // is `androidx.security.crypto` — Android-only. The whole probe
      // + fallback dance, including the eager `storage.readAll()` call
      // in the `case null:` branch, exists for that one cohort.
      //
      // On every other platform (the `else` branch below) we skip the
      // hybrid entirely: fss9 and fss10 route to the same OS-native
      // secure store with byte-identical wire semantics (e.g. iOS:
      // both hit Keychain via `SecItemAdd` / `SecItemCopyMatching`
      // with the same service id + key + accessibility class), so the
      // fallback serves no purpose there and the eager keychain read
      // is what causes the pre-warm `-25308` failure class.
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
            // Never auto-delete data on errors or run an implicit migration.
            // With the fork's StorageCipherFactory patch, this also makes fresh
            // installs initialize the cipher cleanly (saved=current when no
            // markers exist). 6.5.2 ESP users hit the explicit error branch
            // and get caught into the FSS9 fallback below.
            const storage = _fss10Storage;
            // Trigger native init by reading. The constructor alone never
            // throws — failures only surface on data access.
            final data = await storage.readAll();
            log.fine(
              'StorageLocator: fss10 readAll returned ${data.length} entries',
            );

            // Belt-and-suspenders: if FSS10 returns empty but data from a prior
            // install exists, treat it as a silent failure and route to FSS9.
            if (data.isEmpty) {
              final priorInstall = await _inspectPriorInstallData();
              // A pre-v5 ("BULL" 0.x) install has no SQLite database — it kept
              // everything in Hive. Probing only for the database made such a
              // device look like a fresh install: it committed to fss10 and its
              // fss9/ESP secrets (seed material included) stayed invisible on
              // every later launch, flag included. Measured on a real
              // 0.4.3 → 6.13 upgrade.
              if (priorInstall.hasDatabase || priorInstall.hasLegacyHiveBoxes) {
                log.warning(
                  'StorageLocator: fss10 readAll returned empty but prior '
                  'install data exists (database: '
                  '${priorInstall.hasDatabase}, hive boxes: '
                  '${priorInstall.hasLegacyHiveBoxes}) '
                  '— silent failure detected, falling back to fss9',
                );
                throw Exception(
                  'FSS10 silent failure: prior install data exists '
                  'but readAll returned 0 entries',
                );
              }
              log.fine(
                'StorageLocator: readAll empty + no database or hive boxes = '
                'fresh install',
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
              log.fine(
                'StorageLocator: fss9 fallback verified and flag written',
              );
            } catch (fss9Error) {
              log.severe(
                message:
                    'StorageLocator: both fss10 and fss9 failed. '
                    'fss10: ${fss10Error.runtimeType}, '
                    'fss9: ${fss9Error.runtimeType}',
                error: fss9Error,
                trace: StackTrace.current,
                category: ReportCategory.migration,
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
              accessibility:
                  fss9.KeychainAccessibility.first_unlock_this_device,
            ),
          );
          secureStorageDatasource = SecureStorageLegacyDatasourceImpl(storage);
          log.fine('StorageLocator: fss9 legacy storage initialized from flag');

        case SeedStorageLibrary.fss10:
          // Previous session committed to FSS10 (cohort A, prior fresh
          // install, or a 6.5.2 user that fell through to FSS10 after the
          // dance — this last case shouldn't happen since fss9-flag is
          // written for that path).
          log.fine(
            'StorageLocator: existing flag is fss10 — using current storage',
          );
          const storage = _fss10Storage;
          secureStorageDatasource = SecureStorageDatasourceImpl(storage);
          log.fine('StorageLocator: fss10 storage initialized from flag');
      }
    } else {
      // Non-Android: fss10 direct, no probe, no fallback. See the
      // `if (Platform.isAndroid)` comment above for the rationale.
      // Normalize any stray `fss9` flag (practically unreachable here
      // but cheap to enforce) so the cohort-based "legacy storage" UI
      // warning in `wallet_bloc.dart` / `home_errors.dart` doesn't
      // surface for current iOS installs.
      log.fine('StorageLocator: non-Android — fss10 direct, no probe');
      const storage = _fss10Storage;
      secureStorageDatasource = SecureStorageDatasourceImpl(storage);

      if (existingLibrary != SeedStorageLibrary.fss10) {
        await seedStoreTypeDatasource.write(
          SeedStoreTypeModel.fromEntity(
            const SeedStoreType(storageLibrary: SeedStorageLibrary.fss10),
          ),
        );
      }
    }

    locator.registerLazySingleton<KeyValueStorageDatasource<String>>(
      () => secureStorageDatasource,
      instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
    );
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<GetAllSeedsUsecase>(
      () => GetAllSeedsUsecase(seedRepository: locator<SeedRepository>()),
    );
  }
}
