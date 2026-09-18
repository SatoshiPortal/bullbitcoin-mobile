import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';

class WatchTransactionOrderSwapUsecase {
  final SwapFacade _swapFacade;

  const WatchTransactionOrderSwapUsecase(this._swapFacade);

  /// Emits a `Result` per event rather than throwing, so a watcher failure is
  /// a value the cubit can switch on like any other.
  ///
  /// The `await for` covers both ways the stream can fail: a throw on
  /// subscribe, and an error event pushed in later. Mapping alone would let
  /// the latter escape as an unhandled zone error, since the cubit has no
  /// `onError`.
  Stream<Result<OrderSwapRecord, TransactionFailure>> execute(
    String localId,
  ) async* {
    try {
      await for (final result in _swapFacade.watchOrder(localId)) {
        yield switch (result) {
          Ok(:final value) => Ok<OrderSwapRecord, TransactionFailure>(value),
          Err(:final failure) => Err<OrderSwapRecord, TransactionFailure>(
            TransactionSwapUnavailableFailure(
              'watchOrder failed: ${failure.runtimeType}',
            ),
          ),
        };
      }
    } catch (e) {
      yield Err(
        TransactionSwapUnavailableFailure(
          'watchOrder failed: ${e.runtimeType}',
        ),
      );
    }
  }
}
