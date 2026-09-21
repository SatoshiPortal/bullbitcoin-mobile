import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// Reads the swap behind a transaction. Boundary for the throwing shared
/// [GetSwapUsecase] — see [GetTransactionWalletUsecase] for the rationale.
class GetTransactionSwapUsecase {
  final GetSwapUsecase _getSwapUsecase;

  const GetTransactionSwapUsecase(this._getSwapUsecase);

  @useResult
  Future<Result<Swap, TransactionFailure>> execute(String swapId) async {
    try {
      return Ok(await _getSwapUsecase.execute(swapId));
    } catch (e, st) {
      log.severe(
        message: 'Failed to load the swap of a transaction',
        error: e,
        trace: st,
      );
      return Err(
        TransactionSwapUnavailableFailure('getSwap failed: ${e.runtimeType}'),
      );
    }
  }
}
