import 'package:secrets/secrets.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/app_startup/data/wallet_startup_adapter.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_wallet_port.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/check_for_existing_default_wallets_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/initialize_required_tor_usecase.dart';
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
    locator.registerFactory<CheckForExistingDefaultWalletsUsecase>(
      () => CheckForExistingDefaultWalletsUsecase(
        walletRepository: locator<WalletRepository>(),
        settingsRepository: locator<SettingsRepository>(),
        secrets: locator<Secrets>(),
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

    // Bloc
    locator.registerFactory<AppStartupBloc>(
      () => AppStartupBloc(
        resetAppDataUsecase: locator<ResetAppDataUsecase>(),
        checkPinCodeExistsUsecase: locator<CheckPinCodeExistsUsecase>(),
        checkForExistingDefaultWalletsUsecase:
            locator<CheckForExistingDefaultWalletsUsecase>(),
        checkBackupUsecase: locator<CheckBackupUsecase>(),
        initializeRequiredTorUsecase: locator<InitializeRequiredTorUsecase>(),
      ),
    );
  }
}
