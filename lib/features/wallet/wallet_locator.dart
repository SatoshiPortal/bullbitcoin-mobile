import 'package:bb_mobile/core/ark/usecases/check_ark_wallet_setup_usecase.dart';
import 'package:bb_mobile/core/ark/usecases/get_ark_wallet_usecase.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_store_type_datasource.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/auto_swap_execution_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/disable_autoswap_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/disable_autoswap_warning_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/ensure_swap_master_key_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/save_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/sync/sync_coordinator.dart';
import 'package:bb_mobile/core/tor/data/usecases/init_tor_usecase.dart';
import 'package:bb_mobile/core/tor/data/usecases/is_tor_required_usecase.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/cancel_wallet_sync_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_backup_needed_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_bitcoin_sync_backend_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/start_wallet_sync_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_electrum_sync_results_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_sync_progress_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecase/get_unconfirmed_incoming_balance_usecase.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_initial_sync_cubit.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_sync_progress_cubit.dart';
import 'package:get_it/get_it.dart';

class WalletLocator {
  static void setup(GetIt locator) {
    // Usecase
    locator.registerFactory<GetUnconfirmedIncomingBalanceUsecase>(
      () => GetUnconfirmedIncomingBalanceUsecase(
        boltzSwapRepository: locator<BoltzSwapRepository>(
          instanceName:
              LocatorInstanceNameConstants.boltzSwapRepositoryInstanceName,
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
        syncCoordinator: locator<SyncCoordinator>(),
        initializeTorUsecase: locator<InitTorUsecase>(),
        checkForTorInitializationOnStartupUsecase:
            locator<IsTorRequiredUsecase>(),
        getUnconfirmedIncomingBalanceUsecase:
            locator<GetUnconfirmedIncomingBalanceUsecase>(),
        getAutoSwapSettingsUsecase: locator<GetAutoSwapSettingsUsecase>(),
        saveAutoSwapSettingsUsecase: locator<SaveAutoSwapSettingsUsecase>(),
        disableAutoswapWarningUsecase: locator<DisableAutoswapWarningUsecase>(),
        disableAutoswapUsecase: locator<DisableAutoswapUsecase>(),
        autoSwapExecutionUsecase: locator<AutoSwapExecutionUsecase>(),
        deleteWalletUsecase: locator<DeleteWalletUsecase>(),
        seedStoreTypeDatasource: locator<SeedStoreTypeDatasource>(),
        checkBackupNeededUsecase: locator<CheckBackupNeededUsecase>(),
        ensureSwapMasterKeyUsecase: locator<EnsureSwapMasterKeyUsecase>(),
      ),
    );

    // App-wide singleton so a foreground CBF sync's progress is observed
    // continuously — see WalletSyncProgressCubit's class doc and
    // WalletRouter for how the same instance is threaded through the
    // wallet routes without ever being closed by route disposal.
    locator.registerLazySingleton<WalletSyncProgressCubit>(
      () => WalletSyncProgressCubit(
        watchWalletSyncProgressUsecase:
            locator<WatchWalletSyncProgressUsecase>(),
        cancelWalletSyncUsecase: locator<CancelWalletSyncUsecase>(),
        startWalletSyncUsecase: locator<StartWalletSyncUsecase>(),
      ),
    );

    // Route-scoped: one fresh instance per visit to the dedicated CBF
    // initial-sync route, keyed by walletId — never reused across visits,
    // and never the app-wide WalletSyncProgressCubit singleton above. See
    // WalletInitialSyncCubit's class doc for why.
    locator.registerFactoryParam<WalletInitialSyncCubit, String, void>(
      (walletId, _) => WalletInitialSyncCubit(
        walletId: walletId,
        watchWalletSyncProgressUsecase:
            locator<WatchWalletSyncProgressUsecase>(),
        getBitcoinSyncBackendUsecase: locator<GetBitcoinSyncBackendUsecase>(),
        startWalletSyncUsecase: locator<StartWalletSyncUsecase>(),
      ),
    );
  }
}
