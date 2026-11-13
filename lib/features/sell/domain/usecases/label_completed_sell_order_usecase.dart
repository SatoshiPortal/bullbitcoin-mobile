import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bb_mobile/features/transactions/transactions_facade.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Writes the privileged exchange-sell labels when a sell order explicitly
/// completes
class LabelCompletedSellOrderUsecase {
  final TransactionsFacade _transactionsFacade;

  LabelCompletedSellOrderUsecase({required this._transactionsFacade});

  @useResult
  Future<Result<void, SellFailure>> execute({required Order order}) async {
    if (order.orderStatus != OrderStatus.completed) return const Ok(null);
    try {
      await _transactionsFacade.labelCompletedExchangeOrders([order]);
      return const Ok(null);
    } catch (e, st) {
      log.warning(
        'Failed to label the completed sell order',
        error: e,
        trace: st,
      );
      return Err(SellUnexpectedFailure('$e'));
    }
  }
}
