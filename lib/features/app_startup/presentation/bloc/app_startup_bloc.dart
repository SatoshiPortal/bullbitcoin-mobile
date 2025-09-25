import 'package:bb_mobile/core/storage/migrations/004_legacy/migrate_v4_legacy_usecase.dart';
import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/migrate_v5_hive_to_sqlite_usecase.dart';
import 'package:bb_mobile/core/storage/migrations/006_seed_mnemonic_to_entropy.dart';
import 'package:bb_mobile/core/storage/requires_migration_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/check_for_existing_default_wallets_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/reset_app_data_usecase.dart';
import 'package:bb_mobile/features/app_unlock/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/check_backup_usecase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_startup_bloc.freezed.dart';
part 'app_startup_event.dart';
part 'app_startup_state.dart';

class AppStartupBloc extends Bloc<AppStartupEvent, AppStartupState> {
  AppStartupBloc({
    required ResetAppDataUsecase resetAppDataUsecase,
    required CheckPinCodeExistsUsecase checkPinCodeExistsUsecase,
    required CheckForExistingDefaultWalletsUsecase
    checkForExistingDefaultWalletsUsecase,
    required MigrateToV5HiveToSqliteToUsecase migrateHiveToSqliteUsecase,
    required MigrateToV4LegacyUsecase migrateLegacyToV04Usecase,
    required RequiresMigrationUsecase requiresMigrationUsecase,
    required CheckBackupUsecase checkBackupUsecase,
    required Migration6SeedMnemonicToEntropy migration6SeedMnemonicToEntropy,
  }) : _resetAppDataUsecase = resetAppDataUsecase,
       _checkPinCodeExistsUsecase = checkPinCodeExistsUsecase,
       _checkForExistingDefaultWalletsUsecase =
           checkForExistingDefaultWalletsUsecase,
       _migrateToV5HiveToSqliteUsecase = migrateHiveToSqliteUsecase,
       _migrateToV4LegacyUsecase = migrateLegacyToV04Usecase,
       _requiresMigrationUsecase = requiresMigrationUsecase,
       _checkBackupUsecase = checkBackupUsecase,
       _migration6SeedMnemonicToEntropy = migration6SeedMnemonicToEntropy,
       super(const AppStartupState.initial()) {
    on<AppStartupStarted>(_onAppStartupStarted);
  }

  final ResetAppDataUsecase _resetAppDataUsecase;
  final CheckPinCodeExistsUsecase _checkPinCodeExistsUsecase;
  final CheckForExistingDefaultWalletsUsecase
  _checkForExistingDefaultWalletsUsecase;
  final MigrateToV5HiveToSqliteToUsecase _migrateToV5HiveToSqliteUsecase;
  final MigrateToV4LegacyUsecase _migrateToV4LegacyUsecase;
  final RequiresMigrationUsecase _requiresMigrationUsecase;
  final CheckBackupUsecase _checkBackupUsecase;
  final Migration6SeedMnemonicToEntropy _migration6SeedMnemonicToEntropy;

  Future<void> _onAppStartupStarted(
    AppStartupStarted event,
    Emitter<AppStartupState> emit,
  ) async {
    emit(const AppStartupState.loadingInProgress());
    try {
      // Run Tor initialization in background
      // SQL Migrations
      // emit(const AppStartupState.failure(null));
      // return;
      final migrationRequired = await _requiresMigrationUsecase.execute();
      if (migrationRequired == null) {
        emit(const AppStartupState.loadingInProgress());
      } else {
        emit(const AppStartupState.loadingInProgress(requiresMigration: true));

        switch (migrationRequired) {
          case MigrationRequired.v4:
            await _migrateToV4LegacyUsecase.execute();
            emit(
              const AppStartupState.loadingInProgress(
                requiresMigration: true,
                v4MigrationComplete: true,
              ),
            );
            await _migrateToV5HiveToSqliteUsecase.execute();
            emit(
              const AppStartupState.loadingInProgress(
                requiresMigration: true,
                v4MigrationComplete: true,
                v5MigrationComplete: true,
              ),
            );
          case MigrationRequired.v5:
            emit(
              const AppStartupState.loadingInProgress(
                requiresMigration: true,
                v4MigrationComplete: true,
              ),
            );
            await _migrateToV5HiveToSqliteUsecase.execute();
            emit(
              const AppStartupState.loadingInProgress(
                requiresMigration: true,
                v4MigrationComplete: true,
                v5MigrationComplete: true,
              ),
            );
        }
      }

      await _migration6SeedMnemonicToEntropy.execute();

      // all here future migration calls
      final doDefaultWalletsExist =
          await _checkForExistingDefaultWalletsUsecase.execute();
      bool isPinCodeSet = false;

      if (doDefaultWalletsExist) {
        isPinCodeSet = await _checkPinCodeExistsUsecase.execute();
        // Other startup logic can be added here, e.g. payjoin sessions resume
      } else {
        // This is a fresh install, so reset the app data that might still be
        //  there from a previous install.
        //  (e.g. secure storage data on iOS like the pin code)
        await _resetAppDataUsecase.execute();
      }

      emit(
        AppStartupState.success(
          isPinCodeSet: isPinCodeSet,
          hasDefaultWallets: doDefaultWalletsExist,
        ),
      );
    } catch (e) {
      bool hasBackup;
      try {
        // Check if there is a backup available
        hasBackup = await _checkBackupUsecase.execute();
      } catch (_) {
        log.severe(
          'Failed to check for backup availability during app startup',
          error: e,
        );
        hasBackup = false;
      }
      emit(AppStartupState.failure(e, hasBackup: hasBackup));
    }
  }
}
