import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Asks the exchange for a fresh quote on the sell's order: a pay order
/// (sell to a recipient) and a sell order (sell to the balance) each have
/// their own refresh; any other order is only re-read.
class RefreshSellOrderUsecase {
  final Exchange _exchange;

  const RefreshSellOrderUsecase(this._exchange);

  Future<Result<Order, ExchangeReadFailure>> execute(
    ExchangeSession session,
    Order order,
  ) async {
    final orders = _exchange.orders(session.environment);
    if (order is FiatPaymentOrder) {
      return readOfResult(await orders.refreshPayOrder(order.orderId));
    }
    if (order is SellOrder) {
      return readOfResult(await orders.refreshSellOrder(order.orderId));
    }
    return readOfResult(await orders.getOrder(order.orderId));
  }
}
