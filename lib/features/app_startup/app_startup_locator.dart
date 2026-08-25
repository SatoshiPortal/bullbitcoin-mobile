import 'dart:io' show Platform;

import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/app_startup/data/wallet_startup_adapter.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_wallet_port.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/check_for_existing_default_wallets_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/check_legacy_install_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/get_legacy_seeds_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/initialize_required_tor_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/get_tor_status_visibility_usecase.dart';
import 'package:bb_mobile/features/electrum_settings/public/electrum_settings_facade.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/reset_app_data_usecase.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/features/app_unlock/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:bb_mobile/features/pin_code/data/repositories/pin_code_repository.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/check_backup_usecase.dart';
import 'package:get_it/get_it.dart';
import 'package:bull_tor/tor.dart';

class AppStartupLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<AppStartupWalletPort>(
      () => WalletStartupAdapter(locator<WalletRepository>()),
    );

    // Use cases
    locator.registerFactory<ResetAppDataUsecase>(
      () =>
          ResetAppDataUsecase(pinCodeRepository: locator<PinCodeRepository>()),
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
    locator.registerFactory<InitializeRequiredTorUsecase>(
      () => InitializeRequiredTorUsecase(
        locator<AppStartupWalletPort>(),
        locator<EnsureTorReadyUsecase>(),
        locator<SettingsRepository>(),
        locator<Tor>(),
      ),
    );
    locator.registerFactory<GetTorStatusVisibilityUsecase>(
      () => GetTorStatusVisibilityUsecase(
        locator<AppStartupWalletPort>(),
        locator<ElectrumSettingsFacade>(),
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
        initializeRequiredTorUsecase: locator<InitializeRequiredTorUsecase>(),
      ),
    );
  }
}
