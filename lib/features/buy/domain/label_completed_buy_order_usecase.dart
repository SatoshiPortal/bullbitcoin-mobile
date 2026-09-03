import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:bb_mobile/features/transactions/transactions_facade.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// Writes the privileged exchange-buy labels when a buy order explicitly
/// completes (issue #2624: labels must never be written from history reads).
class LabelCompletedBuyOrderUsecase {
  final TransactionsFacade _transactionsFacade;

  LabelCompletedBuyOrderUsecase({required this._transactionsFacade});

  @useResult
  Future<Result<void, BuyFailure>> execute({required Order order}) async {
    if (order.orderStatus != OrderStatus.completed) return const Ok(null);
    try {
      await _transactionsFacade.labelCompletedExchangeOrders([order]);
      return const Ok(null);
    } catch (e, st) {
      log.warning(
        'Failed to label the completed buy order',
        error: e,
        trace: st,
      );
      return Err(BuyUnexpectedFailure('$e'));
    }
  }
}
