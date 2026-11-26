import 'package:swaps/order_swaps.dart';
import 'package:primitives/primitives.dart';
import 'package:send/src/payment/domain/send_failure.dart';
import 'package:send/src/payment/domain/swap_failure_to_send_failure.dart';
import 'package:meta/meta.dart';

class WatchSendSwapUsecase {
  final OrderSwaps _swapFacade;

  const WatchSendSwapUsecase(this._swapFacade);

  @useResult
  Stream<Result<OrderSwapRecord, SendFailure>> execute(String localId) =>
      _swapFacade
          .watchOrder(localId)
          .map((result) => result.mapErr(mapSwapFailureToSendFailure));
}
