import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Reads the active limit orders of the exchange's current session.
class GetActiveLimitOrdersUsecase {
  final Exchange _exchange;

  const GetActiveLimitOrdersUsecase(this._exchange);

  /// The active limit orders of [session]'s account; without a session the
  /// answer is the signed-out one.
  Future<ExchangeRead<List<LimitOrder>>> execute(
    ExchangeSession? session,
  ) async => readOfResult(switch (session) {
    null => const Err(ExchangeNotAuthenticatedFailure()),
    final session => await _exchange.limitOrders.listActive(session),
  });
}
