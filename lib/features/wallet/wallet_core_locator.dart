import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/wallet/data/wallet_sync_binding.dart';

import 'package:sync/write.dart' show ElectrumSync, WalletNativeRuntime;

import 'package:primitives/primitives.dart'
    show Err, NetworkCapabilities, NetworkCapability, Ok;
import 'package:secrets/secrets.dart'
    show WalletInventory, WalletRegistrationNotFoundFailure;
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:get_it/get_it.dart';
import 'package:sync/sync.dart'
    show
        SyncInvalidCatalogFailure,
        SyncNotFoundFailure,
        SyncStorageFailure,
        SyncUnsupportedNetworkFailure,
        Wallet,
        WalletKey,
        WalletSnapshotException;

class WalletLocator {
  /// Resolves the runtime lazily so composition can wire ports before startup.
  static Future<Wallet> Function(String) walletAccess(GetIt locator) =>
      (walletId) async {
        final key = switch (await locator<WalletInventory>().readWallet(
          walletId,
        )) {
          Ok(:final value) => WalletKey(id: value.id, network: value.network),
          Err(failure: WalletRegistrationNotFoundFailure()) =>
            throw const WalletSnapshotException(SyncNotFoundFailure()),
          Err() => throw const WalletSnapshotException(SyncStorageFailure()),
        };
        if (!NetworkCapabilities.supports(
          key.network,
          NetworkCapability.softwareWallet,
        )) {
          throw const WalletSnapshotException(SyncUnsupportedNetworkFailure());
        }
        return WalletSyncBinding.value(
          (await locator<WalletNativeRuntime>().wallet(key)).mapErr(
            // The authorized row exists, but its exact native handle does not.
            (failure) => failure is SyncNotFoundFailure
                ? const SyncInvalidCatalogFailure()
                : failure,
          ),
        );
      };

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<GetWalletsUsecase>(
      () => GetWalletsUsecase(
        settingsRepository: locator<ActiveEnvironmentReader>(),
        walletRepository: locator<WalletRepository>(),
      ),
    );
    locator.registerFactory<WatchStartedWalletSyncsUsecase>(
      () => WatchStartedWalletSyncsUsecase(
        walletRepository: locator<WalletRepository>(),
      ),
    );
    locator.registerFactory<WatchFinishedWalletSyncsUsecase>(
      () => WatchFinishedWalletSyncsUsecase(
        walletRepository: locator<WalletRepository>(),
      ),
    );
    locator.registerFactory<CheckWalletSyncingUsecase>(
      () => CheckWalletSyncingUsecase(locator<ElectrumSync>().isSyncing),
    );
  }
}
