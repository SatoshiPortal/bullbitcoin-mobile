import 'package:provisioning/provisioning.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_wallet_amount_display_usecase.dart';


import 'domain/usecases/load_network_wallet_setup_usecase.dart';
import 'domain/usecases/create_network_wallet_usecase.dart';
import 'presentation/network_wallet_setup_cubit.dart';

import 'package:electrum/electrum.dart' show ElectrumSyncResult;



import 'package:bb_mobile/features/wallet/domain/usecases/watch_wallet_revisions_usecase.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bb_mobile/features/wallet/data/sync_wallet_values_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/data/wallet_registrations.dart';
import 'package:bb_mobile/features/wallet/data/wallet_sync_binding.dart';
import 'package:sync/write.dart';
import 'package:bull_tor/tor.dart';
import 'package:silent/silent.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_sp_feature_gate_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_sp_scanning_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_sp_wallet_setup_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/refresh_sp_wallet_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_sp_wallet_usecase.dart';
import 'package:swaps/swaps.dart';
import 'package:overview/setup.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_backup_needed_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/read_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_unconfirmed_incoming_balance_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_external_tor_proxy_status_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/sync_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_wallet_sync_events_usecase.dart';
import 'package:swap_feature/swap_feature.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/retry_swaps_on_refresh_usecase.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:get_it/get_it.dart';


class WalletLocator {
  static void setup(GetIt locator) {
    OverviewSynchronization overviewSync() =>
        locator<OverviewSynchronization>();

    locator.registerFactory<LoadNetworkWalletSetupUsecase>(
      () => LoadNetworkWalletSetupUsecase(
        locator<DeveloperEnvironmentReader>(),
        locator<SecretsInventory>(),
        locator<Secrets>(),
      ),
    );
    locator.registerFactory<CreateNetworkWalletUsecase>(
      () => CreateNetworkWalletUsecase(
        locator<DeveloperEnvironmentReader>(),
        locator<SecretsInventory>(),
        locator<Secrets>(),
        locator<DefaultWalletProvisioning>(),
      ),
    );
    locator.registerFactory<NetworkWalletSetupCubit>(
      () => NetworkWalletSetupCubit(
        locator<LoadNetworkWalletSetupUsecase>(),
        locator<CreateNetworkWalletUsecase>(),
      ),
    );
    locator.registerLazySingleton<SyncWalletValuesDatasource>(
      () => SyncWalletValuesDatasource(
        load: (key) async => WalletSyncBinding.value(
          await locator<WalletNativeRuntime>().loadWallet(key),
        ),
      ),
    );

    locator.registerLazySingleton<WalletRepository>(() {
      final electrum = locator<ElectrumSync>();
      return WalletRepository(
        walletRegistrations: locator<WalletRegistrations>(),
        walletValuesDatasource: locator<SyncWalletValuesDatasource>(),
        synchronization: locator<ForegroundWalletSynchronization>(),
        syncStarted: electrum.started.map((key) => key.id),
        syncFinished: electrum.finished.map((event) => event.key.id),
      );
    });
    locator.registerFactory<CheckBackupNeededUsecase>(
      () => CheckBackupNeededUsecase(
        walletRepository: locator<WalletRepository>(),
        settingsRepository: locator<ActiveEnvironmentReader>(),
        backupStatus: locator<RecoverBullFacade>().status,
      ),
    );
    // Usecase
    locator.registerFactory<GetUnconfirmedIncomingBalanceUsecase>(
      () =>
          GetUnconfirmedIncomingBalanceUsecase(swapStore: locator<SwapStore>()),
    );
    locator.registerFactory<GetExternalTorProxyStatusUsecase>(
      () => GetExternalTorProxyStatusUsecase(
        locator<TorProxyPreferencesReader>(),
        locator<Tor>(),
      ),
    );
    locator.registerFactory<CheckSpWalletSetupForWalletUsecase>(
      () => CheckSpWalletSetupForWalletUsecase(silent: locator<Silent>()),
    );
    locator.registerFactory<CheckSpFeatureGateForWalletUsecase>(
      () => CheckSpFeatureGateForWalletUsecase(silent: locator<Silent>()),
    );
    locator.registerFactory<CheckSpScanningForWalletUsecase>(
      () => CheckSpScanningForWalletUsecase(silent: locator<Silent>()),
    );
    locator.registerFactory<RefreshSpWalletForWalletUsecase>(
      () => RefreshSpWalletForWalletUsecase(silent: locator<Silent>()),
    );
    locator.registerFactory<WatchSpWalletUsecase>(
      () => WatchSpWalletUsecase(silent: locator<Silent>()),
    );

    locator.registerFactory<SyncWalletsUsecase>(
      () => SyncWalletsUsecase(overviewSync().coordinator.sync),
    );
    locator.registerFactory<WatchWalletSyncEventsUsecase>(
      () => WatchWalletSyncEventsUsecase(
        watchStarted: locator<WatchStartedWalletSyncsUsecase>(),
        watchFinished: locator<WatchFinishedWalletSyncsUsecase>(),
        watchElectrum: () =>
            ElectrumSyncResult.watch(locator<ElectrumSync>().finished),
      ),
    );
    // Bloc
    locator.registerFactory<WalletBloc>(
      () => WalletBloc(
        watchAmountDisplayUsecase: WatchWalletAmountDisplayUsecase(
          locator<AmountDisplayPreferencesReader>(),
        ),
        watchWalletRevisionsUsecase: WatchWalletRevisionsUsecase(
          locator<WalletNativeRuntime>().changes,
        ),
        retrySwapsOnRefreshUsecase: RetrySwapsOnRefreshUsecase(
          locator<SwapActivity>(),
        ),
        checkSpWalletSetupForWalletUsecase:
            locator<CheckSpWalletSetupForWalletUsecase>(),
        checkSpScanningForWalletUsecase:
            locator<CheckSpScanningForWalletUsecase>(),
        refreshSpWalletForWalletUsecase:
            locator<RefreshSpWalletForWalletUsecase>(),
        watchSpWalletUsecase: locator<WatchSpWalletUsecase>(),
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        readWalletUsecase: ReadWalletUsecase(locator<WalletRepository>()),
        checkWalletSyncingUsecase: locator<CheckWalletSyncingUsecase>(),
        watchWalletSyncEventsUsecase: locator<WatchWalletSyncEventsUsecase>(),
        syncWalletsUsecase: locator<SyncWalletsUsecase>(),
        getUnconfirmedIncomingBalanceUsecase:
            locator<GetUnconfirmedIncomingBalanceUsecase>(),
        checkBackupNeededUsecase: locator<CheckBackupNeededUsecase>(),
        getExternalTorProxyStatusUsecase:
            locator<GetExternalTorProxyStatusUsecase>(),
        checkSpFeatureGateForWalletUsecase:
            locator<CheckSpFeatureGateForWalletUsecase>(),
      ),
    );
  }
}
