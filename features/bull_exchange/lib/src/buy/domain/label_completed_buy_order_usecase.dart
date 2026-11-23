import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_exchange/src/buy/domain/buy_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// Writes the privileged exchange-buy labels when a buy order explicitly
/// completes (issue #2624: labels must never be written from history reads).
class LabelCompletedBuyOrderUsecase {
  final Future<void> Function(List<Order>) _labelOrders;

  LabelCompletedBuyOrderUsecase(this._labelOrders);

  @useResult
  Future<Result<void, BuyFailure>> execute({required Order order}) async {
    if (order.orderStatus != OrderStatus.completed) return const Ok(null);
    try {
      await _labelOrders([order]);
      return const Ok(null);
    } on Exception catch (e, st) {
      log.warning(
        'Failed to label the completed buy order',
        error: e.runtimeType,
        trace: st,
      );
      return Err(BuyUnexpectedFailure(e.runtimeType.toString()));
    }
  }
}
