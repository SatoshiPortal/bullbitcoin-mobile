import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Reads the limit-order rate (index and user price) in [Market]'s
/// currency. The exchange serves it without a session.
class GetLimitOrderRateUsecase {
  final Exchange _exchange;

  const GetLimitOrderRateUsecase(this._exchange);

  Future<Result<LimitOrderRate, ExchangeReadFailure>> execute(
    ExchangeSession session,
    Market market,
  ) async => readOfResult(
    await _exchange.limitOrders.getRate(session, market.currency.code),
  );
}
