import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:overview/overview.dart';
import 'package:swap_feature/swap_feature.dart';
import 'package:overview/setup.dart';

final class CoordinatedSwapSync implements SwapSyncPort {
  final SyncCoordinator<Wallet, WalletFailure> _coordinator;

  const CoordinatedSwapSync(this._coordinator);

  @override
  Future<OrderSwapPollingAttempt> request() async {
    SwapFailure? failure;
    try {
      await _coordinator.sync(only: {SyncKind.swaps});
    } on SyncCoordinatorException catch (error) {
      // The legacy queue aggregates Errors as well as recoverable failures.
      for (final cause in error.failures.values) {
        if (cause is Error) throw cause;
      }
      failure = const SwapUnexpectedFailure('Scheduled swap refresh failed');
    }
    final outcome = _coordinator.lastSwapSyncOutcome;
    return OrderSwapPollingAttempt(
      lastOutcome: switch (outcome?.kind) {
        null => null,
        SyncOutcomeKind.active => const OrderSwapPolling.active(),
        SyncOutcomeKind.idle => const OrderSwapPolling.idle(),
        SyncOutcomeKind.rateLimited => OrderSwapPolling.rateLimited(
          retryAfter: outcome?.retryAfter,
        ),
      },
      failure: failure,
    );
  }
}
