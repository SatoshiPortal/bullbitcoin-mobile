import 'package:swaps/swaps.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// Reads the swap behind a transaction, mapping the engine's failure into the
/// transactions family.
class GetTransactionSwapUsecase {
  final GetSwapUsecase _getSwapUsecase;

  const GetTransactionSwapUsecase(this._getSwapUsecase);

  @useResult
  Future<Result<Swap, TransactionFailure>> execute(String swapId) async {
    switch (await _getSwapUsecase.execute(swapId: swapId)) {
      case Ok(:final value):
        return Ok(value);
      case Err(:final failure):
        log.warning(
          'Swap of a transaction not loaded (${failure.runtimeType})',
        );
        return Err(
          TransactionSwapUnavailableFailure(
            'getSwap failed: ${failure.runtimeType}',
          ),
        );
    }
  }
}
