import 'package:bull_exchange/src/buy/domain/buy_payjoin_uris.dart';
import 'package:bull_exchange/src/orders/domain/usecases/get_order_usecase.dart';
import 'package:exchange/exchange.dart';

/// Reads the buy order the done page watches: the shared order read, any
/// other order class is malformed, and the order keeps the payjoin URI its
/// create attached.
class GetBuyOrderUsecase {
  final GetOrderUsecase _getOrder;
  final BuyPayjoinUris _uris;

  const GetBuyOrderUsecase(this._getOrder, this._uris);

  Future<ExchangeRead<BuyOrder>> execute(
    ExchangeSession session,
    String orderId,
  ) async => switch (await _getOrder.execute(session, orderId)) {
    ReadGot(value: final BuyOrder order) => ReadGot(_uris.withBip21(order)),
    ReadGot() => const ReadMalformed('not a buy order'),
    ReadMissing() => const ReadMissing(),
    ReadUnreachable(:final reason, :final isNetwork) => ReadUnreachable(
      reason,
      isNetwork: isNetwork,
    ),
    ReadSessionRejected(:final why) => ReadSessionRejected(why),
    ReadMalformed(:final reason) => ReadMalformed(reason),
  };
}
