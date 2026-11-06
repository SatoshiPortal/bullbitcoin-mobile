import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/wallet/data/wallet_native_runtime.dart';
import 'data/sync_coordinator.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:get_it/get_it.dart';

class SyncLocator {
  static void setupForeground(GetIt locator) {
    SyncLocator.setup(
      locator,
      syncSwapsOutcome: () async {
        final result = await locator<SwapFacade>().refreshOrdersWithOutcome();
        switch (result) {
          case Ok(:final value):
            final rateLimited = value.failures
                .whereType<SwapRateLimitedFailure>()
                .firstOrNull;
            if (rateLimited != null) {
              return SyncOutcome.rateLimited(
                retryAfter: rateLimited.retryAfter,
                failure: _SwapSyncException(rateLimited.runtimeType),
              );
            }
            return value.pollableOrderCount == 0
                ? const SyncOutcome.idle()
                : const SyncOutcome.active();
          case Err(:final failure):
            return failure is SwapRateLimitedFailure
                ? SyncOutcome.rateLimited(
                    retryAfter: failure.retryAfter,
                    failure: _SwapSyncException(failure.runtimeType),
                  )
                : SyncOutcome.rateLimited(
                    failure: _SwapSyncException(failure.runtimeType),
                  );
        }
      },
      // Lazy, like the swap callback above: SpLocator runs after this, and the
      // closure only resolves the facade when a sync tick actually fires.
      syncSp: () async {
        final result = await locator<SpFacade>().syncWallet();
        if (result case Err(:final failure)) {
          throw SpSyncException(failure.logMessage);
        }
      },
    );
  }

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

final class _SwapSyncException implements Exception {
  final Type failureType;

  const _SwapSyncException(this.failureType);
}

Future<void> initializeWalletRuntime(GetIt locator) =>
    locator<WalletNativeRuntime>().initialize();
