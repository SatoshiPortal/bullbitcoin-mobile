import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/storage/migrations/004_legacy/migrate_v4_legacy_usecase.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/migrate_v5_hive_to_sqlite_usecase.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/new_seed_repository.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_hive_datasource.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_seed_repository.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/old/old_wallet_repository.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/secure_storage_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/check_for_existing_default_wallets_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/reset_app_data_usecase.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/app_unlock/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:bb_mobile/features/pin_code/domain/repositories/pin_code_repository.dart';
import 'package:bb_mobile/locator.dart';

class AppStartupLocator {
  static void setup() {
    // Use cases
    locator.registerFactory<ResetAppDataUsecase>(
      () =>
          ResetAppDataUsecase(pinCodeRepository: locator<PinCodeRepository>()),
    );
    locator.registerFactory<CheckForExistingDefaultWalletsUsecase>(
      () => CheckForExistingDefaultWalletsUsecase(
        walletRepository: locator<WalletRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactoryAsync<MigrateToV5HiveToSqliteToUsecase>(() async {
      final migrationSecureStorage = MigrationSecureStorageDatasource();
      final newSeedRepository = NewSeedRepository(migrationSecureStorage);
      final oldSeedRepository = OldSeedRepository(migrationSecureStorage);
      final oldHiveDatasource = await OldHiveDatasource.init();
      final oldWalletRepository = OldWalletRepository(oldHiveDatasource);
      return MigrateToV5HiveToSqliteToUsecase(
        newSeedRepository: newSeedRepository,
        oldSeedRepository: oldSeedRepository,
        oldWalletRepository: oldWalletRepository,
      );
    });
    locator.registerFactory<MigrateToV4LegacyUsecase>(
      () => MigrateToV4LegacyUsecase(MigrationSecureStorageDatasource()),
    );

    // Bloc
    locator.registerFactoryAsync<AppStartupBloc>(
      () async => AppStartupBloc(
        resetAppDataUsecase: locator<ResetAppDataUsecase>(),
        checkPinCodeExistsUsecase: locator<CheckPinCodeExistsUsecase>(),
        checkForExistingDefaultWalletsUsecase:
            locator<CheckForExistingDefaultWalletsUsecase>(),
        migrateHiveToSqliteUsecase:
            await locator.getAsync<MigrateToV5HiveToSqliteToUsecase>(),
        migrateLegacyToV04Usecase: locator<MigrateToV4LegacyUsecase>(),
      ),
    );
  }
}
