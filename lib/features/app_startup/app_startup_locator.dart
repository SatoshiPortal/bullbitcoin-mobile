import 'dart:io' show Platform;

import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/tor/data/usecases/init_tor_usecase.dart';
import 'package:bb_mobile/core/tor/data/usecases/is_tor_required_usecase.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/check_for_existing_default_wallets_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/check_legacy_install_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/get_legacy_seeds_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/reset_app_data_usecase.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/app_unlock/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';
import 'package:bb_mobile/features/recoverbull/presentation/telemetry/recoverbull_telemetry_cubit.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/check_backup_usecase.dart';
import 'package:get_it/get_it.dart';

class AppStartupLocator {
  static void setup(GetIt locator) {
    // Use cases
    locator.registerFactory<ResetAppDataUsecase>(
      () => ResetAppDataUsecase(
        pinCodeRepository: locator<PinCodeRepository>(),
        recoverBullRepository: locator<RecoverBullRepository>(),
      ),
    );
    locator.registerFactory<CheckLegacyInstallUsecase>(
      () => CheckLegacyInstallUsecase(
        secureStorage: locator<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
        isAndroid: Platform.isAndroid,
      ),
    );
    locator.registerFactory<GetLegacySeedsUsecase>(
      () => GetLegacySeedsUsecase(
        secureStorage: locator<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
      ),
    );
    locator.registerFactory<CheckForExistingDefaultWalletsUsecase>(
      () => CheckForExistingDefaultWalletsUsecase(
        walletRepository: locator<WalletRepository>(),
        settingsRepository: locator<SettingsRepository>(),
        seedRepository: locator<SeedRepository>(),
      ),
    );

    // Bloc
    locator.registerFactory<AppStartupBloc>(
      () => AppStartupBloc(
        resetAppDataUsecase: locator<ResetAppDataUsecase>(),
        checkPinCodeExistsUsecase: locator<CheckPinCodeExistsUsecase>(),
        checkForExistingDefaultWalletsUsecase:
            locator<CheckForExistingDefaultWalletsUsecase>(),
        checkLegacyInstallUsecase: locator<CheckLegacyInstallUsecase>(),
        checkBackupUsecase: locator<CheckBackupUsecase>(),
        isTorRequiredUsecase: locator<IsTorRequiredUsecase>(),
        initTorUsecase: locator<InitTorUsecase>(),
        recoverbullTelemetryCubit: locator<RecoverbullTelemetryCubit>(),
      ),
    );
  }
}
