import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:exchange/exchange.dart';

/// Reads one order of the session's account.
class GetOrderUsecase {
  final Exchange _exchange;

  const GetOrderUsecase(this._exchange);

  Future<ExchangeRead<Order>> execute(
    ExchangeSession session,
    String orderId,
  ) async => readOfResult(
    await _exchange.orders(session.environment).getOrder(orderId),
  );
}
