import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:exchange/exchange.dart';

/// The re-read after a create whose outcome is unknown: settles the journal
/// entries the exchange can decide first, so a create seen here no longer
/// holds the write gate, then reads the recent limit orders of the
/// exchange's current session.
class GetRecentLimitOrdersUsecase {
  final Exchange _exchange;

  const GetRecentLimitOrdersUsecase(this._exchange);

  Future<ExchangeRead<List<LimitOrder>>> execute() async {
    final _ = await _exchange.reconcileUnknownWrites();
    return readOfResult(await _exchange.limitOrders.listRecent());
  }
}
