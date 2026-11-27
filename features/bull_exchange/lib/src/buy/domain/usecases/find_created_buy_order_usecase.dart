import 'package:bull_exchange/src/buy/domain/buy_state.dart';
import 'package:bull_exchange/src/buy/domain/buy_payjoin_uris.dart';
import 'package:bull_exchange/src/orders/domain/usecases/find_created_order_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// After a buy create whose outcome is unknown: the shared find of the
/// order it made; a found order takes the payjoin URI that create attached.
class FindCreatedBuyOrderUsecase {
  final FindCreatedOrderUsecase _findCreatedOrder;
  final BuyPayjoinUris _uris;

  const FindCreatedBuyOrderUsecase(this._findCreatedOrder, this._uris);

  Future<Result<BuyOrder, ExchangeReadFailure>> execute(
    ExchangeSession session,
    BuyRequest request,
    DateTime sentAt,
  ) async {
    final read = await _findCreatedOrder.execute<BuyOrder>(
      session,
      request.journal,
      sentAt,
    );
    if (read case Ok(value: final found)) {
      _uris.adopt(request, found.orderId);
      return Ok(_uris.withBip21(found));
    }
    return read;
  }
}
