import 'package:swaps/order_swaps.dart';
import 'package:primitives/primitives.dart';
import 'package:receive/receive.dart';
import 'package:meta/meta.dart';

class WatchReceiveOrderSwapUsecase {
  final OrderSwaps _swapFacade;

  const WatchReceiveOrderSwapUsecase(this._swapFacade);

  @useResult
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
