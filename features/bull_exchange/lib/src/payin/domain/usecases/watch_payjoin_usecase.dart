import 'package:bull_exchange/src/payin/payin_spend_answers.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:exchange/steps.dart';
import 'package:primitives/primitives.dart';

/// The progress of payjoin session [sessionId]: its stored state first, then
/// every change while it is ongoing. Ends on a failed read.
class WatchPayjoinUsecase {
  final PayjoinSessions _payjoinSessions;

  const WatchPayjoinUsecase(this._payjoinSessions);

  Stream<PayjoinProgress> execute(String sessionId) async* {
    switch (await _payjoinSessions.byId(sessionId)) {
      case Ok(value: final session?):
        yield payjoinProgressOf(session);
        if (!session.isOngoing) return;
      case Ok():
        break;
      case Err():
        return;
    }
    await for (final result in _payjoinSessions.watch(
      sessionIds: {sessionId},
    )) {
      switch (result) {
        case Ok(:final value):
          yield payjoinProgressOf(value);
        case Err():
          return;
      }
    }
  }
}
