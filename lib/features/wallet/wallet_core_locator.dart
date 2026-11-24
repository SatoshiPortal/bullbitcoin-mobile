import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/wallet/data/wallet_sync_binding.dart';

import 'package:sync/write.dart' show ElectrumSync, WalletNativeRuntime;

import 'package:sync/sync.dart' show CoinFreezes;
import 'package:bb_mobile/features/wallet/data/wallet_registrations.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:get_it/get_it.dart';
import 'package:sync/sync.dart' show Sync, Wallet;

class WalletLocator {
  /// Resolves the runtime lazily so composition can wire ports before startup.
  static ({
    Future<Sync> Function() foreground,
    Future<Wallet> Function(String walletId) openWallet,
  })
  syncAccess(GetIt locator) => (
    foreground: () async => WalletSyncBinding.value(
      await locator<WalletNativeRuntime>().foreground(),
    ),
    openWallet: (walletId) async => WalletSyncBinding.value(
      await locator<WalletNativeRuntime>().wallet(
        await WalletSyncBinding.keyForId(
          locator<WalletRegistrations>(),
          walletId,
        ),
      ),
    ),
  );

  static Future<void> registerDatasources(GetIt locator) async {
    locator.registerLazySingleton<CoinFreezes>(
      () => CoinFreezes(
        sync: () async => WalletSyncBinding.value(
          await locator<WalletNativeRuntime>().foreground(),
        ),
      ),
    );
  }

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
