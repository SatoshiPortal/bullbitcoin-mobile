import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:meta/meta.dart';

class GetTransactionOrderSwapUsecase {
  final SwapFacade _swapFacade;

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
