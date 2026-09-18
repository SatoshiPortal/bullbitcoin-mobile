import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/watch_swap_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';

/// Watches the swap behind a transaction.
///
/// Emits a `Result` per event rather than throwing, so a watcher failure is a
/// value the cubit can switch on like any other. The shared [WatchSwapUsecase]
/// can throw on subscribe and into the stream; the `await for` covers both.
class WatchTransactionSwapUsecase {
  final WatchSwapUsecase _watchSwapUsecase;

  const WatchTransactionSwapUsecase(this._watchSwapUsecase);

  Stream<Result<Swap, TransactionFailure>> execute(String swapId) async* {
    try {
      await for (final swap in _watchSwapUsecase.execute(swapId)) {
        yield Ok(swap);
      }
    } catch (e) {
      yield Err(
        TransactionSwapUnavailableFailure('watchSwap failed: ${e.runtimeType}'),
      );
    }
  }
}
