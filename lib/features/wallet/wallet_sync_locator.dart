import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/data/coordinated_swap_sync.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/sync_order_swaps_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/sync_sp_for_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/wallet/data/sync_coordinator.dart';
import 'package:bb_mobile/features/wallet/data/wallet_native_runtime.dart';
import 'package:get_it/get_it.dart';
import 'package:primitives/primitives.dart';

class SyncLocator {
  static void setupForeground(GetIt locator) {
    locator.registerFactory<SyncOrderSwapsUsecase>(
      () => SyncOrderSwapsUsecase(locator<SwapFacade>()),
    );
    locator.registerFactory<SyncSpForWalletUsecase>(
      () => SyncSpForWalletUsecase(locator<SpFacade>()),
    );
    SyncLocator.setup(
      locator,
      syncSwapsOutcome: () => locator<SyncOrderSwapsUsecase>().execute(),
      syncSpOutcome: () => locator<SyncSpForWalletUsecase>().execute(),
    );
    locator.registerLazySingleton<SwapSyncPort>(
      () => CoordinatedSwapSync(locator<SyncCoordinator>()),
    );
  }

  /// Foreground-only. The background-task isolate uses its own GetIt and
  /// must not register the coordinator (its lifecycle listener has no
  /// widget binding to attach to in that isolate).
  ///
  /// [syncSp] is a lazy closure resolved at call time, like the swap
  /// callbacks, so feature resolution waits until the first sync tick.
  static void setup(
    GetIt locator, {
    Future<void> Function()? syncSwaps,
    Future<SyncOutcome> Function()? syncSwapsOutcome,
    Future<void> Function()? syncSp,
    Future<Result<void, WalletFailure>> Function()? syncSpOutcome,
  }) {
    locator.registerLazySingleton<SyncCoordinator>(
      () => SyncCoordinator(
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        syncWalletUsecase: locator<SyncWalletUsecase>(),
        syncSwaps: syncSwaps,
        syncSwapsOutcome: syncSwapsOutcome,
        syncSp: syncSp,
        syncSpOutcome: syncSpOutcome,
        refreshRevisions: () => locator<WalletNativeRuntime>().refreshAll(),
      ),
    );
  }
}

Future<void> initializeWalletRuntime(GetIt locator) =>
    locator<WalletNativeRuntime>().initialize();
