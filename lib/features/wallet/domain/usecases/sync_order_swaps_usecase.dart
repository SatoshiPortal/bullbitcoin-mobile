import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/wallet/domain/sync_outcome.dart';
import 'package:primitives/primitives.dart';

class SyncOrderSwapsUsecase {
  final SwapFacade _swaps;

  const SyncOrderSwapsUsecase(this._swaps);

  Future<SyncOutcome> execute() async {
    switch (await _swaps.refreshOrdersWithOutcome()) {
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
        return SyncOutcome.rateLimited(
          retryAfter: failure is SwapRateLimitedFailure
              ? failure.retryAfter
              : null,
          failure: _SwapSyncException(failure.runtimeType),
        );
    }
  }
}

final class _SwapSyncException implements Exception {
  final Type failureType;

  const _SwapSyncException(this.failureType);
}
