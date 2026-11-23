import 'package:swaps/order_swaps.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/swap_failure_to_send_failure.dart';
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
