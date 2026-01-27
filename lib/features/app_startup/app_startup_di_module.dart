import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/check_for_existing_default_wallets_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/reset_app_data_usecase.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';

class AppStartupDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {}

  @override
  Future<void> registerDrivenAdapters() async {}

  @override
  Future<void> registerApplicationServices() async {}

  @override
  Future<void> registerUseCases() async {
    // Use cases
    sl.registerFactory<ResetAppDataUsecase>(
      () => ResetAppDataUsecase(pinCodeRepository: sl()),
    );
    sl.registerFactory<CheckForExistingDefaultWalletsUsecase>(
      () => CheckForExistingDefaultWalletsUsecase(
        walletRepository: sl(),
        settingsRepository: sl(),
        seedRepository: sl(),
      ),
    );
  }

  @override
  Future<void> registerDrivingAdapters() async {
    // Bloc
    sl.registerFactory<AppStartupBloc>(
      () => AppStartupBloc(
        resetAppDataUsecase: sl(),
        checkPinCodeExistsUsecase: sl(),
        checkForExistingDefaultWalletsUsecase: sl(),
        migrateHiveToSqliteUsecase: sl(),
        migrateLegacyToV04Usecase: sl(),
        requiresMigrationUsecase: sl(),
        checkBackupUsecase: sl(),
        isTorRequiredUsecase: sl(),
        initTorUsecase: sl(),
      ),
    );
  }
}
