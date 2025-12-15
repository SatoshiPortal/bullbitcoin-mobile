import 'package:bb_mobile/core_deprecated/ark/usecases/check_ark_wallet_setup_usecase.dart';
import 'package:bb_mobile/core_deprecated/ark/usecases/get_ark_wallet_usecase.dart';
import 'package:bb_mobile/core_deprecated/settings/data/settings_repository.dart';
import 'package:bb_mobile/core_deprecated/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core_deprecated/swaps/domain/usecases/auto_swap_execution_usecase.dart';
import 'package:bb_mobile/core_deprecated/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core_deprecated/swaps/domain/usecases/restart_swap_watcher_usecase.dart';
import 'package:bb_mobile/core_deprecated/swaps/domain/usecases/save_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core_deprecated/tor/data/usecases/init_tor_usecase.dart';
import 'package:bb_mobile/core_deprecated/tor/data/usecases/is_tor_required_usecase.dart';
import 'package:bb_mobile/core_deprecated/utils/constants.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/usecases/watch_electrum_sync_results_usecase.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecase/get_unconfirmed_incoming_balance_usecase.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/locator.dart';

class WalletLocator {
  static void setup() {
    // Usecase
    locator.registerFactory<GetUnconfirmedIncomingBalanceUsecase>(
      () => GetUnconfirmedIncomingBalanceUsecase(
        settingsRepository: locator<SettingsRepository>(),
        mainnetBoltzSwapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
        ),
        testnetBoltzSwapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants
                  .boltzTestnetSwapRepositoryInstanceName,
        ),
      ),
    );

    // Bloc
    locator.registerFactory<WalletBloc>(
      () => WalletBloc(
        getArkWalletUsecase: locator<GetArkWalletUsecase>(),
        checkArkWalletSetupUsecase: locator<CheckArkWalletSetupUsecase>(),
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        checkWalletSyncingUsecase: locator<CheckWalletSyncingUsecase>(),
        watchStartedWalletSyncsUsecase:
            locator<WatchStartedWalletSyncsUsecase>(),
        watchFinishedWalletSyncsUsecase:
            locator<WatchFinishedWalletSyncsUsecase>(),
        watchElectrumSyncResultsUsecase:
            locator<WatchElectrumSyncResultsUsecase>(),
        restartSwapWatcherUsecase: locator<RestartSwapWatcherUsecase>(),
        initializeTorUsecase: locator<InitTorUsecase>(),
        checkForTorInitializationOnStartupUsecase:
            locator<IsTorRequiredUsecase>(),
        getUnconfirmedIncomingBalanceUsecase:
            locator<GetUnconfirmedIncomingBalanceUsecase>(),
        getAutoSwapSettingsUsecase: locator<GetAutoSwapSettingsUsecase>(),
        saveAutoSwapSettingsUsecase: locator<SaveAutoSwapSettingsUsecase>(),
        autoSwapExecutionUsecase: locator<AutoSwapExecutionUsecase>(),
        deleteWalletUsecase: locator<DeleteWalletUsecase>(),
      ),
    );
  }
}
