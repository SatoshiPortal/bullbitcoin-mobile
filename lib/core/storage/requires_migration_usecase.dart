import 'dart:io' show Platform;

import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/entities/old_storage_keys.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/secure_storage_datasource.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

enum MigrationRequired { v4, v5 }

class RequiresMigrationUsecase {
  final MigrationSecureStorageDatasource _migrationSecureStorageDatasource;
  final WalletRepository _newWalletRepository;

  RequiresMigrationUsecase(
    this._migrationSecureStorageDatasource,
    this._newWalletRepository,
  );

  Future<MigrationRequired?> execute() async {
    // Android is the ONLY platform that ever shipped a v0.1-v0.4 BULL
    // build (2023-2024). Every other platform (iOS, macOS, web, Linux,
    // Windows) released after the v5.0 SQLite migration, so no install
    // can carry a legacy `OldStorageKeys.version` marker. Short-
    // circuiting here:
    //  - eliminates the secure-storage read that throws -25308 on
    //    iOS pre-first-unlock pre-warm launches (the second remaining
    //    keychain surface during early startup, alongside the now-
    //    short-circuited `OldHiveDatasource`)
    //  - keeps `MigrateToV4LegacyUsecase` and `MigrateToV5...Usecase`
    //    from ever being invoked on non-Android — both already guarded
    //    by an empty `OldHiveDatasource.getValue` return, but stopping
    //    upstream is cleaner than relying on the inner guard
    if (!Platform.isAndroid) {
      log.config('Migration: skipped (non-Android — no Hive history)');
      return null;
    }

    final fromVersion = await _migrationSecureStorageDatasource.fetch(
      key: OldStorageKeys.version.name,
    );
    if (fromVersion == null) {
      log.fine('FINE: Migration not required');
      return null;
    }
    if (fromVersion.startsWith('0.1') ||
        fromVersion.startsWith('0.2') ||
        fromVersion.startsWith('0.3')) {
      log.fine('FINE: Migration Required: v4');
      return MigrationRequired.v4;
    }

    final newMainnetDefaultWallets = await _newWalletRepository.getWallets(
      onlyDefaults: true,
      environment: Environment.mainnet,
    );
    if (newMainnetDefaultWallets.length < 2 && fromVersion.startsWith('0.4')) {
      log.fine('FINE: Migration Required: v5');
      return MigrationRequired.v5;
    }
    log.fine('FINE: Migration Not Required');
    return null;
  }
}
