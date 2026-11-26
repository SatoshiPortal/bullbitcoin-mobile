import 'package:bull_exchange/src/buy/domain/buy_payjoin_uris.dart';
import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:exchange/exchange.dart';

/// Asks the exchange for a fresh quote on the buy order, keeping the
/// payjoin URI its create attached.
class RefreshBuyOrderUsecase {
  final Exchange _exchange;
  final BuyPayjoinUris _uris;

  const RefreshBuyOrderUsecase(this._exchange, this._uris);

  Future<ExchangeRead<BuyOrder>> execute(
    ExchangeSession session,
    String orderId,
  ) async => switch (readOfResult(
    await _exchange.orders(session.environment).refreshBuyOrder(orderId),
  )) {
    ReadGot(:final value) => ReadGot(_uris.withBip21(value)),
    final other => other,
  };
}
