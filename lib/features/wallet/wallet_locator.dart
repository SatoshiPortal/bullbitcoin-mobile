import 'package:bb_mobile/core/seed/data/datasources/seed_store_type_datasource.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bull_tor/tor.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_sp_feature_gate_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_sp_scanning_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_sp_wallet_setup_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/refresh_sp_wallet_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_sp_wallet_usecase.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/sync/sync_coordinator.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_backup_needed_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/delete_wallet_usecase.dart'
    as core;
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_electrum_sync_results_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_unconfirmed_incoming_balance_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_external_tor_proxy_status_usecase.dart';
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
    locator.registerFactory<GetExternalTorProxyStatusUsecase>(
      () => GetExternalTorProxyStatusUsecase(
        locator<SettingsRepository>(),
        locator<Tor>(),
      ),
    );
    locator.registerFactory<CheckSpWalletSetupForWalletUsecase>(
      () => CheckSpWalletSetupForWalletUsecase(spFacade: locator<SpFacade>()),
    );
    locator.registerFactory<CheckSpFeatureGateForWalletUsecase>(
      () => CheckSpFeatureGateForWalletUsecase(spFacade: locator<SpFacade>()),
    );
    locator.registerFactory<CheckSpScanningForWalletUsecase>(
      () => CheckSpScanningForWalletUsecase(spFacade: locator<SpFacade>()),
    );
    locator.registerFactory<RefreshSpWalletForWalletUsecase>(
      () => RefreshSpWalletForWalletUsecase(spFacade: locator<SpFacade>()),
    );
    locator.registerFactory<WatchSpWalletUsecase>(
      () => WatchSpWalletUsecase(spFacade: locator<SpFacade>()),
    );

    // Bloc
    locator.registerFactory<WalletBloc>(
      () => WalletBloc(
        checkSpWalletSetupForWalletUsecase:
            locator<CheckSpWalletSetupForWalletUsecase>(),
        checkSpScanningForWalletUsecase:
            locator<CheckSpScanningForWalletUsecase>(),
        refreshSpWalletForWalletUsecase:
            locator<RefreshSpWalletForWalletUsecase>(),
        watchSpWalletUsecase: locator<WatchSpWalletUsecase>(),
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        checkWalletSyncingUsecase: locator<CheckWalletSyncingUsecase>(),
        watchStartedWalletSyncsUsecase:
            locator<WatchStartedWalletSyncsUsecase>(),
        watchFinishedWalletSyncsUsecase:
            locator<WatchFinishedWalletSyncsUsecase>(),
        watchElectrumSyncResultsUsecase:
            locator<WatchElectrumSyncResultsUsecase>(),
        syncCoordinator: locator<SyncCoordinator>(),
        getUnconfirmedIncomingBalanceUsecase:
            locator<GetUnconfirmedIncomingBalanceUsecase>(),
        deleteWalletUsecase: locator<DeleteWalletUsecase>(),
        seedStoreTypeDatasource: locator<SeedStoreTypeDatasource>(),
        checkBackupNeededUsecase: locator<CheckBackupNeededUsecase>(),
        getExternalTorProxyStatusUsecase:
            locator<GetExternalTorProxyStatusUsecase>(),
        checkSpFeatureGateForWalletUsecase:
            locator<CheckSpFeatureGateForWalletUsecase>(),
      ),
    );
  }
}
