import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';

class WatchTransactionOrderSwapUsecase {
  final SwapFacade _swapFacade;

  const WatchTransactionOrderSwapUsecase(this._swapFacade);

  /// Emits a `Result` per event rather than throwing, so a watcher failure is
  /// a value the cubit can switch on like any other.
  Stream<Result<OrderSwapRecord, TransactionFailure>> execute(String localId) {
    return _swapFacade.watchOrder(localId).map((result) {
      return switch (result) {
        Ok(:final value) => Ok<OrderSwapRecord, TransactionFailure>(value),
        Err(:final failure) => Err<OrderSwapRecord, TransactionFailure>(
          TransactionSwapUnavailableFailure(
            'watchOrder failed: ${failure.runtimeType}',
          ),
        ),
      };
    });
  }
}
