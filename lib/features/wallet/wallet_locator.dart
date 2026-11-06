import 'package:secrets/secrets.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart'
    as settings;
import 'package:bb_mobile/features/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/data/wallet_native_runtime.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_transaction_repository_impl.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/data/foreground_wallet_sync.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_catalog_port_impl.dart';
import 'package:transaction_sync/transaction_sync.dart';
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
import 'package:bb_mobile/features/wallet/domain/usecases/sync_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_wallet_sync_events_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:get_it/get_it.dart';

class WalletLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<CreateDefaultWalletsUsecase>(
      () => CreateDefaultWalletsUsecase(
        secrets: locator<Secrets>(),
        settingsRepository: locator<settings.SettingsRepository>(),
        walletRepository: locator<WalletRepository>(),
        resumeProvisioning: locator<WalletNativeRuntime>().resumeProvisioning,
      ),
    );

    locator.registerLazySingleton<WalletNativeRuntime>(
      () => WalletNativeRuntime(
        catalog: locator<WalletCatalogPort>(),
        reserved: locator<ReservedAddressPort>(),
        metadata: locator<WalletMetadataDatasource>(),
        sync: locator<ElectrumSync>(),
        documentsDirectory: () async =>
            (await getApplicationDocumentsDirectory()).path,
      ),
    );
    locator.registerLazySingleton<BdkWalletDatasource>(
      () => BdkWalletDatasource(
        readWallet: locator<WalletNativeRuntime>().bitcoin,
      ),
    );
    locator.registerLazySingleton<LwkWalletDatasource>(
      () => LwkWalletDatasource(
        readWallet: locator<WalletNativeRuntime>().liquid,
      ),
    );
    locator.registerLazySingleton<WalletAddressRepository>(
      () => WalletAddressRepository(
        native: locator<WalletNativeRuntime>(),
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        bdkWalletDatasource: locator<BdkWalletDatasource>(),
        lwkWalletDatasource: locator<LwkWalletDatasource>(),
        labelsFacade: locator<LabelsFacade>(),
      ),
    );

    locator.registerLazySingleton<WalletCatalogPort>(
      () => WalletCatalogPortImpl(locator<WalletMetadataDatasource>()),
    );
    locator.registerLazySingleton<ElectrumSync>(
      () => ElectrumSync(
        connections: locator<WalletConnectionPolicy>(),
        documentsDirectory: () async =>
            (await getApplicationDocumentsDirectory()).path,
      ),
    );
    locator.registerLazySingleton<ForegroundWalletSync>(
      () => ForegroundWalletSync(
        locator<ElectrumSync>(),
        native: locator<WalletNativeRuntime>(),
      ),
    );
    locator.registerLazySingleton<WalletRepository>(() {
      final sync = locator<ForegroundWalletSync>();
      return WalletRepository(
        native: locator<WalletNativeRuntime>(),
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        bdkWalletDatasource: locator<BdkWalletDatasource>(),
        lwkWalletDatasource: locator<LwkWalletDatasource>(),
        synchronize: sync.synchronize,
        isSyncing: sync.isSyncing,
        syncStarted: sync.started,
        syncFinished: sync.finished,
        electrumSyncResultStream: sync.results,
      );
    });
    locator.registerLazySingleton<WalletTransactionRepository>(
      () => WalletTransactionRepositoryImpl(
        walletMetadataDatasource: locator<WalletMetadataDatasource>(),
        labelsFacade: locator<LabelsFacade>(),
        bdkWalletTransactionDatasource: locator<BdkWalletDatasource>(),
        lwkWalletTransactionDatasource: locator<LwkWalletDatasource>(),
        synchronize: locator<ForegroundWalletSync>().synchronize,
      ),
    );
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

    locator.registerFactory<SyncWalletsUsecase>(
      () => SyncWalletsUsecase(locator<SyncCoordinator>()),
    );
    locator.registerFactory<WatchWalletSyncEventsUsecase>(
      () => WatchWalletSyncEventsUsecase(
        watchStarted: locator<WatchStartedWalletSyncsUsecase>(),
        watchFinished: locator<WatchFinishedWalletSyncsUsecase>(),
        watchElectrum: locator<WatchElectrumSyncResultsUsecase>(),
      ),
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
        watchWalletSyncEventsUsecase: locator<WatchWalletSyncEventsUsecase>(),
        syncWalletsUsecase: locator<SyncWalletsUsecase>(),
        getUnconfirmedIncomingBalanceUsecase:
            locator<GetUnconfirmedIncomingBalanceUsecase>(),
        deleteWalletUsecase: locator<DeleteWalletUsecase>(),
        checkBackupNeededUsecase: locator<CheckBackupNeededUsecase>(),
        getExternalTorProxyStatusUsecase:
            locator<GetExternalTorProxyStatusUsecase>(),
        checkSpFeatureGateForWalletUsecase:
            locator<CheckSpFeatureGateForWalletUsecase>(),
      ),
    );
  }
}
