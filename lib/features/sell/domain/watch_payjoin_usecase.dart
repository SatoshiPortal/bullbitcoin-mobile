import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

class WatchPayjoinUsecase {
  final PayjoinSessions _sessions;

  const WatchPayjoinUsecase(this._sessions);

  Stream<PayjoinSession> execute(String sessionId) async* {
    final current = await _sessions.byId(sessionId);
    switch (current) {
      case Ok(:final value):
        if (value != null) {
          yield value;
          if (!value.isOngoing) return;
        }
      case Err():
        throw WatchPayjoinException('Failed to load Payjoin');
    }

    await for (final result in _sessions.watch(sessionIds: {sessionId})) {
      switch (result) {
        case Ok(:final value):
          yield value;
        case Err():
          throw WatchPayjoinException('Failed to watch Payjoin');
      }
    }
  }
}

class WatchPayjoinException extends BullException {
  WatchPayjoinException(super.message);
}
