import 'package:bb_mobile/core/seed/data/datasources/seed_store_type_datasource.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
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
import 'package:bb_mobile/core/wallet/domain/usecases/check_private_wallet_session_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/delete_wallet_public_projection_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/lock_private_wallet_session_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/mount_wallet_with_private_capability_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/update_wallet_label_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_visible_wallet_catalog_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/wallet_signing_material_resolver.dart';
import 'package:bb_mobile/features/wallet/domain/usecase/get_unconfirmed_incoming_balance_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/delete_wallet_usecase.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
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
    // Public surface
    locator.registerLazySingleton<WalletFacade>(() {
      final wallets = locator<WalletRepository>();
      final resolver = locator<WalletSigningMaterialResolver>();
      return WalletFacade(
        MountWalletWithPrivateCapabilityUsecase(wallets, resolver),
        LockPrivateWalletSessionUsecase(resolver),
        CheckPrivateWalletSessionUsecase(resolver),
        WatchVisibleWalletCatalogUsecase(
          wallets,
          locator<SettingsRepository>(),
          resolver,
        ),
        DeleteWalletPublicProjectionUsecase(wallets, resolver),
        UpdateWalletLabelUsecase(wallets),
      );
    });
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
        walletFacade: locator<WalletFacade>(),
      ),
    );
  }
}
