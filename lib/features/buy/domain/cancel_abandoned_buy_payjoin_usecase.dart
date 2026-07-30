import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/cancel_payjoin_receiver_usecase.dart';
import 'package:bb_mobile/core/payjoin/domain/usecases/get_payjoins_usecase.dart';

class CancelAbandonedBuyPayjoinUsecase {
  final GetPayjoinsUsecase _getPayjoinsUsecase;
  final CancelPayjoinReceiverUsecase _cancelPayjoinReceiverUsecase;

  const CancelAbandonedBuyPayjoinUsecase(
    this._getPayjoinsUsecase,
    this._cancelPayjoinReceiverUsecase,
  );

  Future<void> execute(BuyOrder? order) async {
    final uri = order?.bip21URI;
    if (order == null || order.isPayinCompleted || uri == null) return;

    final payjoins = await _getPayjoinsUsecase.execute(onlyOngoing: true);
    for (final payjoin in payjoins) {
      if (payjoin case PayjoinReceiver(
        :final id,
        :final pjUri,
      ) when pjUri == uri) {
        await _cancelPayjoinReceiverUsecase.execute(id);
        return;
      }
    }
  }
}
