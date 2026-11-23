import 'package:primitives/primitives.dart';
import 'package:swaps/order_swaps.dart';
import 'package:transactions/src/domain/transaction_failure.dart';
import 'package:meta/meta.dart';

class GetTransactionOrderSwapsUsecase {
  final ReadOrderSwaps _swapFacade;

  const GetTransactionOrderSwapsUsecase(this._swapFacade);

  @useResult
  Future<Result<List<OrderSwapRecord>, TransactionFailure>> execute({
    String? walletId,
  }) async {
    return switch (await _swapFacade.getOrders(walletId: walletId)) {
      Ok(:final value) => Ok(value),
      Err(:final failure) => Err(
        TransactionSwapUnavailableFailure(
          'getOrders failed: ${failure.runtimeType}',
        ),
      ),
    };
  }
}
