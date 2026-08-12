import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';

class WatchReceiveOrderSwapUsecase {
  final SwapFacade _swapFacade;

  const WatchReceiveOrderSwapUsecase(this._swapFacade);

  Stream<Result<OrderSwapRecord, ReceiveFailure>> execute(String localId) =>
      _swapFacade
          .watchOrder(localId)
          .map((result) => result.mapErr(_mapFailure));

  ReceiveFailure _mapFailure(SwapFailure failure) => switch (failure) {
    SwapNetworkFailure() ||
    SwapTimeoutFailure() => ReceiveNetworkFailure(failure.logMessage),
    SwapRateLimitedFailure(:final retryAfter) => ReceiveRateLimitedFailure(
      retryAfter: retryAfter,
      logMessage: failure.logMessage,
    ),
    _ => ReceiveUnexpectedFailure(failure.logMessage),
  };
}
