import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/swap_failure_to_send_failure.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';

class WatchSendSwapUsecase {
  final SwapFacade _swapFacade;

  const WatchSendSwapUsecase(this._swapFacade);

  Stream<Result<OrderSwapRecord, SendFailure>> execute(String localId) =>
      _swapFacade
          .watchOrder(localId)
          .map((result) => result.mapErr(mapSwapFailureToSendFailure));
}
