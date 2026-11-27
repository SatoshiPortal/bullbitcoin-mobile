import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Reads the index price of bitcoin in [Market]'s currency, the rate the
/// amount steps convert with. The exchange serves it without a session.
class GetMarketRateUsecase {
  final Exchange _exchange;

  const GetMarketRateUsecase(this._exchange);

  Future<ExchangeRead<double>> execute(
    ExchangeSession session,
    Market market,
  ) async => switch (await _exchange.limitOrders.getRate(
    session,
    market.currency.code,
  )) {
    Ok(:final value) => ReadGot(value.indexPrice),
    Err(:final failure) => readOfExchangeFailure(failure),
  };
}
