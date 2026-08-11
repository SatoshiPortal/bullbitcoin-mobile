import 'package:bb_mobile/core/seed/data/datasources/seed_store_type_datasource.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/ensure_swap_master_key_usecase.dart';
import 'package:bb_mobile/core/sync/sync_coordinator.dart';
import 'package:bb_mobile/core/tor/data/usecases/init_tor_usecase.dart';
import 'package:bb_mobile/core/tor/data/usecases/is_tor_required_usecase.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_backup_needed_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/delete_wallet_usecase.dart'
    as core;
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_electrum_sync_results_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecase/get_unconfirmed_incoming_balance_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
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
    locator.registerFactory<DeleteWalletUsecase>(
      () => DeleteWalletUsecase(
        locator<core.DeleteWalletUsecase>(),
        locator<SwapFacade>(),
      ),
    );
    // Bloc
    locator.registerFactory<WalletBloc>(
      () => WalletBloc(
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
        deleteWalletUsecase: locator<DeleteWalletUsecase>(),
        seedStoreTypeDatasource: locator<SeedStoreTypeDatasource>(),
        checkBackupNeededUsecase: locator<CheckBackupNeededUsecase>(),
        ensureSwapMasterKeyUsecase: locator<EnsureSwapMasterKeyUsecase>(),
      ),
    );
  }
}
