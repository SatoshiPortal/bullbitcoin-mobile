import 'package:bull_exchange/src/buy/domain/buy_payjoin_uris.dart';
import 'package:bull_exchange/src/orders/domain/usecases/get_order_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Reads the buy order the done page watches: the shared order read, any
/// other order class is malformed, and the order keeps the payjoin URI its
/// create attached.
class GetBuyOrderUsecase {
  final GetOrderUsecase _getOrder;
  final BuyPayjoinUris _uris;

  const GetBuyOrderUsecase(this._getOrder, this._uris);

  Future<Result<BuyOrder, ExchangeReadFailure>> execute(
    ExchangeSession session,
    String orderId,
  ) async => switch (await _getOrder.execute(session, orderId)) {
    Ok(value: final BuyOrder order) => Ok(_uris.withBip21(order)),
    Ok() => const Err(ExchangeMalformedFailure('not a buy order')),
    Err(failure: ExchangeMissingFailure()) => const Err(
      ExchangeMissingFailure(),
    ),
    Err(failure: ExchangeUnreachableFailure(:final reason, :final isNetwork)) =>
      Err(ExchangeUnreachableFailure(reason, isNetwork: isNetwork)),
    Err(failure: ExchangeSessionRejectedFailure(:final why)) => Err(
      ExchangeSessionRejectedFailure(why),
    ),
    Err(failure: ExchangeMalformedFailure(:final reason)) => Err(
      ExchangeMalformedFailure(reason),
    ),
  };
}
