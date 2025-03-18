import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/_core/domain/services/mnemonic_seed_factory.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager_service.dart';
import 'package:bb_mobile/app_startup/domain/usecases/check_for_existing_default_wallets_usecase.dart';
import 'package:bb_mobile/app_startup/domain/usecases/init_wallets_usecase.dart';
import 'package:bb_mobile/app_startup/domain/usecases/reset_app_data_usecase.dart';
import 'package:bb_mobile/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:bb_mobile/app_unlock/domain/usecases/check_pin_code_exists_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/onboarding/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/pin_code/domain/repositories/pin_code_repository.dart';

class AppStartupLocator {
  static void setup() {
    // Use cases
    locator.registerFactory<ResetAppDataUsecase>(
      () => ResetAppDataUsecase(
        pinCodeRepository: locator<PinCodeRepository>(),
      ),
    );
    locator.registerFactory<CheckForExistingDefaultWalletsUsecase>(
      () => CheckForExistingDefaultWalletsUsecase(
        walletManager: locator<WalletManagerService>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<InitExistingWalletsUsecase>(
      () => InitExistingWalletsUsecase(
        walletManager: locator<WalletManagerService>(),
      ),
    );
    // Use cases
    locator.registerFactory<CreateDefaultWalletsUsecase>(
      () => CreateDefaultWalletsUsecase(
        settingsRepository: locator<SettingsRepository>(),
        mnemonicSeedFactory: locator<MnemonicSeedFactory>(),
        walletManager: locator<WalletManagerService>(),
      ),
    );

    // Bloc
    locator.registerFactory<AppStartupBloc>(
      () => AppStartupBloc(
        resetAppDataUsecase: locator<ResetAppDataUsecase>(),
        checkPinCodeExistsUsecase: locator<CheckPinCodeExistsUsecase>(),
        checkForExistingDefaultWalletsUsecase:
            locator<CheckForExistingDefaultWalletsUsecase>(),
        initExistingWalletsUsecase: locator<InitExistingWalletsUsecase>(),
      ),
    );
  }
}
