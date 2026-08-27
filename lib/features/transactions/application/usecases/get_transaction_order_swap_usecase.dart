import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_error.dart';

class GetTransactionOrderSwapUsecase {
  final SwapFacade _swapFacade;

  const GetTransactionOrderSwapUsecase(this._swapFacade);

  Future<OrderSwapRecord> execute(String localId) async {
    return switch (await _swapFacade.getOrder(localId)) {
      Ok(:final value) => value,
      Err(failure: SwapOrderNotFoundFailure()) =>
        throw TransactionNotFoundError(),
      Err() => throw TransactionError('Failed to load swap transaction'),
    };
  }
}
