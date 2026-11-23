import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:secrets/secrets.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/app_startup/data/wallet_startup_adapter.dart';
import 'package:bb_mobile/features/app_startup/domain/app_startup_wallet_port.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/check_for_existing_default_wallets_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/initialize_required_tor_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/restore_missing_default_secret_usecase.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/start_swap_engine_usecase.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/app_startup_bloc.dart';
import 'package:access/access.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/get_startup_pin_status_usecase.dart';
import 'package:swaps/swaps.dart';
import 'package:get_it/get_it.dart';
import 'package:bull_tor/tor.dart';

class AppStartupLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<AppStartupWalletPort>(
      () => WalletStartupAdapter(
        locator<WalletRepository>(),
        (context) => locator<RecoverBullFacade>().status(context),
      ),
    );

    // Use cases
    locator.registerFactory<CheckForExistingDefaultWalletsUsecase>(
      () => CheckForExistingDefaultWalletsUsecase(
        walletRepository: locator<WalletRepository>(),
        settingsRepository: locator<Preferences>(),
        secrets: locator<Secrets>(),
      ),
    );
    locator.registerFactory<RestoreMissingDefaultSecretUsecase>(
      () => RestoreMissingDefaultSecretUsecase(
        secrets: locator<Secrets>(),
        walletRepository: locator<WalletRepository>(),
      ),
    );
    locator.registerFactory<InitializeRequiredTorUsecase>(
      () => InitializeRequiredTorUsecase(
        locator<AppStartupWalletPort>(),
        locator<EnsureTorReadyUsecase>(),
        locator<Preferences>(),
        locator<Tor>(),
      ),
    );
    locator.registerFactory<StartSwapEngineUsecase>(
      () => StartSwapEngineUsecase(
        locator<LogSwapCensusUsecase>(),
        locator<SwapWatcher>(),
      ),
    );

    // Bloc
    locator.registerFactory<AppStartupBloc>(
      () => AppStartupBloc(
        getStartupPinStatusUsecase: const GetStartupPinStatusUsecase(Access()),
        checkForExistingDefaultWalletsUsecase:
            locator<CheckForExistingDefaultWalletsUsecase>(),
        initializeRequiredTorUsecase: locator<InitializeRequiredTorUsecase>(),
        restoreMissingDefaultSecretUsecase:
            locator<RestoreMissingDefaultSecretUsecase>(),
        startSwapEngineUsecase: locator<StartSwapEngineUsecase>(),
      ),
    );
  }
}
