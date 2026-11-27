import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Asks the exchange for a fresh quote on the pay order.
class RefreshPayOrderUsecase {
  final Exchange _exchange;

  const RefreshPayOrderUsecase(this._exchange);

  Future<Result<Order, ExchangeReadFailure>> execute(
    ExchangeSession session,
    String orderId,
  ) async => readOfResult(
    await _exchange.orders(session.environment).refreshPayOrder(orderId),
  );
}
