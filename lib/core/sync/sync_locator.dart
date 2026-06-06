import 'package:bb_mobile/core/sync/sync_coordinator.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/restart_swap_watcher_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:get_it/get_it.dart';

class SyncLocator {
  /// Foreground-only. The background-task isolate uses its own GetIt and
  /// must not register the coordinator (its lifecycle listener has no
  /// widget binding to attach to in that isolate).
  static void setup(GetIt locator) {
    locator.registerLazySingleton<SyncCoordinator>(
      () => SyncCoordinator(
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        syncWalletUsecase: locator<SyncWalletUsecase>(),
        restartSwapWatcherUsecase: locator<RestartSwapWatcherUsecase>(),
      ),
    );
  }
}
