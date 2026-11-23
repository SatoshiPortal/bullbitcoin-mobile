import 'package:primitives/primitives.dart';
import 'package:receive/receive.dart';
import 'package:meta/meta.dart';

class WatchReceiveOrderSwapUsecase {
  final ReadOrderSwaps Function() _orderSwaps;

  const WatchReceiveOrderSwapUsecase(this._orderSwaps);

  @useResult
  Stream<Result<OrderSwapRecord, ReceiveFailure>> execute(String localId) =>
      _orderSwaps()
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
