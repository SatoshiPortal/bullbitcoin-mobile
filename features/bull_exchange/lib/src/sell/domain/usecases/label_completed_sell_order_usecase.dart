import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/sell/domain/sell_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Writes the privileged exchange-sell labels when a sell order explicitly
/// completes
class LabelCompletedSellOrderUsecase {
  final Future<void> Function(List<Order>) _labelOrders;

  LabelCompletedSellOrderUsecase(this._labelOrders);

  @useResult
  Future<Result<void, SellFailure>> execute({required Order order}) async {
    if (order.orderStatus != OrderStatus.completed) return const Ok(null);
    try {
      await _labelOrders([order]);
      return const Ok(null);
    } catch (e, st) {
      log.warning(
        'Failed to label the completed sell order',
        error: e.runtimeType,
        trace: st,
      );
      return Err(SellUnexpectedFailure(e.runtimeType.toString()));
    }
  }
}
