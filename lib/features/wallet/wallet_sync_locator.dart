import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure_log_code.dart';
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:sync/sync.dart' show WalletKey;
import 'package:bb_mobile/features/wallet/data/wallet_sync_binding.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/read_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/data/coordinated_swap_sync.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/sync_order_swaps_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/sync_sp_for_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:silent/silent.dart';
import 'package:swap_feature/swap_feature.dart';
import 'package:overview/setup.dart';
import 'package:sync/write.dart' show WalletNativeRuntime;
import 'package:get_it/get_it.dart';
import 'package:primitives/primitives.dart';

class SyncLocator {
  static void setupForeground(GetIt locator) {
    locator.registerFactory<SyncOrderSwapsUsecase>(
      () => SyncOrderSwapsUsecase(locator<SwapActivity>()),
    );
    locator.registerFactory<SyncSpForWalletUsecase>(
      () => SyncSpForWalletUsecase(locator<Silent>()),
    );
    SyncLocator.setup(
      locator,
      syncSwapsOutcome: () => locator<SyncOrderSwapsUsecase>().execute(),
      syncSpOutcome: () => locator<SyncSpForWalletUsecase>().execute(),
    );
    locator.registerLazySingleton<SwapSyncPort>(
      () => CoordinatedSwapSync(
        locator<SyncCoordinator<Wallet, WalletFailure>>(),
      ),
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
    locator.registerLazySingleton<SyncCoordinator<Wallet, WalletFailure>>(
      () => SyncCoordinator<Wallet, WalletFailure>(
        walletKey: (wallet) =>
            WalletKey(id: wallet.id, network: wallet.network.shared),
        classifyFailure: (failure) =>
            (empty: failure is NoWalletsFoundFailure, code: failure.logCode),
        readNetwork: () async => ((await locator<Preferences>().fetch()).fold(
          (value) => value,
          (failure) => throw Exception('Preferences read failed'),
        )).environment.networkEnv,
        readWallet: ReadWalletUsecase(locator<WalletRepository>()).execute,
        getWallets: locator<GetWalletsUsecase>().execute,
        syncWallet: locator<SyncWalletUsecase>().execute,
        syncSwaps: syncSwaps,
        syncSwapsOutcome: syncSwapsOutcome,
        syncSp: syncSp,
        syncSpOutcome: syncSpOutcome,
        refreshRevisions: () async => WalletSyncBinding.value(
          await locator<WalletNativeRuntime>().refreshAll(),
        ),
      ),
    );
  }
}

Future<void> initializeWalletRuntime(WalletNativeRuntime runtime) async {
  // Startup continues when native stores are unavailable, as before.
  await runtime.initialize();
}
