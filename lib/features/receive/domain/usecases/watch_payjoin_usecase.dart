import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';

class WatchPayjoinUsecase {
  final PayjoinSessions _sessions;

  const WatchPayjoinUsecase(this._sessions);

  /// Live updates for the watched payjoin sessions.
  ///
  /// A failed update is *yielded* as an [Err], never thrown: this stream feeds
  /// the receive screen for as long as it is open, and an error on it would
  /// cancel the subscription and freeze the payjoin state with no way to
  /// recover. The `throw` this replaced also escaped as an unhandled async
  /// error, since the bloc's `listen` has no `onError`.
  @useResult
  Stream<Result<PayjoinSession, ReceiveFailure>> execute({
    List<String>? ids,
  }) async* {
    await for (final result in _sessions.watch(sessionIds: ids?.toSet())) {
      switch (result) {
        case Ok(:final value):
          yield Ok(value);
        case Err(:final failure):
          yield Err(ReceivePayjoinUnavailableFailure(failure.logMessage));
      }
    }
  }
}
