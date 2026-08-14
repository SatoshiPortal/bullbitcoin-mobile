import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/features/transactions/transactions_facade.dart';

/// Writes the privileged exchange-buy labels when a buy order explicitly
/// completes (issue #2624: labels must never be written from history reads).
class LabelCompletedBuyOrderUsecase {
  final TransactionsFacade _transactionsFacade;

  LabelCompletedBuyOrderUsecase({required this._transactionsFacade});

  Future<void> execute({required Order order}) async {
    if (order.orderStatus != OrderStatus.completed) return;
    await _transactionsFacade.labelCompletedExchangeOrders([order]);
  }
}
