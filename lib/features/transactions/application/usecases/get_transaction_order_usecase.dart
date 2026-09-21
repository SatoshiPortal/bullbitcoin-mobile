import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// Reads the exchange order behind a transaction. Boundary for the throwing
/// shared [GetOrderUsecase].
class GetTransactionOrderUsecase {
  final GetOrderUsecase _getOrderUsecase;

  const GetTransactionOrderUsecase(this._getOrderUsecase);

  @useResult
  Future<Result<Order, TransactionFailure>> execute(String orderId) async {
    try {
      return Ok(await _getOrderUsecase.execute(orderId: orderId));
    } catch (e, st) {
      log.severe(
        message: 'Failed to load the order of a transaction',
        error: e,
        trace: st,
      );
      return Err(
        TransactionUnexpectedFailure('getOrder failed: ${e.runtimeType}'),
      );
    }
  }
}
