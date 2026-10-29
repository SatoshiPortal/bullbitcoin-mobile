import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'data/wallet_sync_status_repository_impl.dart';
import 'domain/repositories/wallet_sync_status_repository.dart';
import 'domain/usecases/start_wallet_sync_usecase.dart';
import 'domain/usecases/watch_cbf_network_policy_usecase.dart';
import 'domain/usecases/set_cbf_wifi_only_usecase.dart';
import 'domain/usecases/continue_cbf_on_mobile_data_usecase.dart';
import 'domain/usecases/watch_wallet_sync_status_usecase.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_sync_settings_repository.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/get_wallet_sync_network_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/load_wallet_sync_settings_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/save_wallet_sync_settings_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/public/wallet_sync_facade.dart';
import 'package:get_it/get_it.dart';

class WalletSyncLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<WalletSyncStatusRepository>(
      () => WalletSyncStatusRepositoryImpl(
        wallets: locator<WalletMetadataDatasource>(),
        settings: locator<SettingsRepository>(),
        sync: locator<WalletTransactionSyncFacade>(),
        metadata: locator<WalletSyncMetadataPort>(),
        networkPolicy: locator<CbfNetworkPolicyPort>(),
      ),
      dispose: (repository) =>
          (repository as WalletSyncStatusRepositoryImpl).dispose(),
    );
    locator.registerLazySingleton<StartWalletSyncUsecase>(
      () => StartWalletSyncUsecase(
        get: locator<GetWalletUsecase>(),
        sync: locator<SyncWalletUsecase>(),
        status: locator<WalletSyncStatusRepository>(),
      ),
    );
    locator.registerFactory<WatchWalletSyncStatusUsecase>(
      () => WatchWalletSyncStatusUsecase(
        repository: locator<WalletSyncStatusRepository>(),
      ),
    );
    locator.registerFactory<WalletSyncFacade>(
      () => WalletSyncFacade(
        watch: locator<WatchWalletSyncStatusUsecase>(),
        start: locator<StartWalletSyncUsecase>(),
        watchNetwork: WatchCbfNetworkPolicyUsecase(
          policy: locator<CbfNetworkPolicyPort>(),
        ),
        setWifiOnly: SetCbfWifiOnlyUsecase(
          policy: locator<CbfNetworkPolicyPort>(),
        ),
        continueOnMobileData: ContinueCbfOnMobileDataUsecase(
          policy: locator<CbfNetworkPolicyPort>(),
        ),
        network: GetWalletSyncNetworkUsecase(
          settings: locator<SettingsRepository>(),
        ),
        load: LoadWalletSyncSettingsUsecase(
          repository: locator<WalletSyncSettingsRepository>(),
        ),
        save: SaveWalletSyncSettingsUsecase(
          start: locator<StartWalletSyncUsecase>(),
          repository: locator<WalletSyncSettingsRepository>(),
        ),
      ),
    );
  }
}
