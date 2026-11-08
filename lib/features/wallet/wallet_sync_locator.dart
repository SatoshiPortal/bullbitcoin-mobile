import 'package:bb_mobile/features/wallet/domain/usecases/read_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/wallet/data/wallet_native_runtime.dart';
import 'package:bb_mobile/core/sync/sync_coordinator.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:get_it/get_it.dart';

class SyncLocator {
  /// Foreground-only. The background-task isolate uses its own GetIt and
  /// must not register the coordinator (its lifecycle listener has no
  /// widget binding to attach to in that isolate).
  ///
  /// [syncSp] is a lazy closure resolved at call time, like the swap
  /// callbacks, so core never imports the SP feature (rule #7).
  static void setup(
    GetIt locator, {
    Future<void> Function()? syncSwaps,
    Future<SyncOutcome> Function()? syncSwapsOutcome,
    Future<void> Function()? syncSp,
  }) {
    locator.registerLazySingleton<SyncCoordinator>(
      () => SyncCoordinator(
        readNetwork: () async =>
            (await locator<SettingsRepository>().fetch()).environment,
        readWalletUsecase: ReadWalletUsecase(locator<WalletRepository>()),
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        syncWalletUsecase: locator<SyncWalletUsecase>(),
        syncSwaps: syncSwaps,
        syncSwapsOutcome: syncSwapsOutcome,
        syncSp: syncSp,
        refreshRevisions: () => locator<WalletNativeRuntime>().refreshAll(),
      ),
    );
  }
}
