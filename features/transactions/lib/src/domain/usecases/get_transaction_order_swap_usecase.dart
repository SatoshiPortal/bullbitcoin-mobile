import 'package:primitives/primitives.dart';
import 'package:swaps/order_swaps.dart';
import 'package:transactions/src/domain/transaction_failure.dart';
import 'package:meta/meta.dart';

class GetTransactionOrderSwapUsecase {
  final ReadOrderSwaps _swapFacade;

  const GetTransactionOrderSwapUsecase(this._swapFacade);

  @useResult
  Future<Result<OrderSwapRecord, TransactionFailure>> execute(
    String localId,
  ) async {
    return switch (await _swapFacade.getOrder(localId)) {
      Ok(:final value) => Ok(value),
      Err(failure: SwapOrderNotFoundFailure()) => const Err(
        TransactionNotFoundFailure('swap order not found'),
      ),
      Err(:final failure) => Err(
        TransactionSwapUnavailableFailure(
          'getOrder failed: ${failure.runtimeType}',
        ),
      ),
    };
  }
}
