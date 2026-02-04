import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/storage/migrations/004_legacy/migrate_v4_legacy_usecase.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/migrate_v5_hive_to_sqlite_usecase.dart';
import 'package:bb_mobile/core/storage/requires_migration_usecase.dart';
import 'package:bb_mobile/core/tor/data/usecases/init_tor_usecase.dart';
import 'package:bb_mobile/core/tor/data/usecases/is_tor_required_usecase.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/check_for_existing_default_wallets_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/reset_app_data_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/secure_storage_dump_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/wallet_metadata_dump_usecase.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/app_unlock/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/check_backup_usecase.dart';
import 'package:get_it/get_it.dart';

class AppStartupLocator {
  static void setup(GetIt locator) {
    // Use cases
    locator.registerFactory<ResetAppDataUsecase>(
      () =>
          ResetAppDataUsecase(pinCodeRepository: locator<PinCodeRepository>()),
    );
    locator.registerFactory<CheckForExistingDefaultWalletsUsecase>(
      () => CheckForExistingDefaultWalletsUsecase(
        walletRepository: locator<WalletRepository>(),
        settingsRepository: locator<SettingsRepository>(),
        seedRepository: locator<SeedRepository>(),
      ),
    );
    locator.registerFactory<WalletMetadataDumpUsecase>(
      () => WalletMetadataDumpUsecase(
        walletRepository: locator<WalletRepository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<SecureStorageDumpUsecase>(
      () => SecureStorageDumpUsecase(
        secureStorage: locator<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
      ),
    );

    // Bloc
    locator.registerFactory<AppStartupBloc>(
      () => AppStartupBloc(
        resetAppDataUsecase: locator<ResetAppDataUsecase>(),
        checkPinCodeExistsUsecase: locator<CheckPinCodeExistsUsecase>(),
        checkForExistingDefaultWalletsUsecase:
            locator<CheckForExistingDefaultWalletsUsecase>(),
        walletMetadataDumpUsecase: locator<WalletMetadataDumpUsecase>(),
        secureStorageDumpUsecase: locator<SecureStorageDumpUsecase>(),
        migrateHiveToSqliteUsecase: locator<MigrateToV5HiveToSqliteToUsecase>(),
        migrateLegacyToV04Usecase: locator<MigrateToV4LegacyUsecase>(),
        requiresMigrationUsecase: locator<RequiresMigrationUsecase>(),
        checkBackupUsecase: locator<CheckBackupUsecase>(),
        isTorRequiredUsecase: locator<IsTorRequiredUsecase>(),
        initTorUsecase: locator<InitTorUsecase>(),
      ),
    );
  }
}
