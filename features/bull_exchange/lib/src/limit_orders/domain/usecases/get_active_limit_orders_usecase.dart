import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:exchange/exchange.dart';

/// Reads the active limit orders of the exchange's current session.
class GetActiveLimitOrdersUsecase {
  final Exchange _exchange;

  const GetActiveLimitOrdersUsecase(this._exchange);

  Future<ExchangeRead<List<LimitOrder>>> execute() async =>
      readOfResult(await _exchange.limitOrders.listActive());
}
