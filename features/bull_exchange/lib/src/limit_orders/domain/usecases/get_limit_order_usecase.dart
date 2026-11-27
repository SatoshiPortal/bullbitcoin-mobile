import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Reads one limit order of the exchange's current session; an order the
/// exchange does not know is [ExchangeMissingFailure], not a failure.
class GetLimitOrderUsecase {
  final Exchange _exchange;

  const GetLimitOrderUsecase(this._exchange);

  Future<Result<LimitOrder, ExchangeReadFailure>> execute(
    ExchangeSession session,
    String orderId,
  ) async => switch (await _exchange.limitOrders.get(session, orderId)) {
    Ok(:final value) => Ok(value),
    Err(
      failure: ExchangeLimitOrderFailure(
        problem: ExchangeLimitOrderProblem.notFound,
      ),
    ) =>
      const Err(ExchangeMissingFailure()),
    Err(:final failure) => readOfExchangeFailure(failure),
  };
}
