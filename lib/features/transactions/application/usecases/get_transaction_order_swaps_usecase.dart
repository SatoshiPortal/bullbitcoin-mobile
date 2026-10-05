import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:meta/meta.dart';

class GetTransactionOrderSwapsUsecase {
  final SwapFacade _swapFacade;

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
