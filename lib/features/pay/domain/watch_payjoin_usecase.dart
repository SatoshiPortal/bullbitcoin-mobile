import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

class WatchPayjoinUsecase {
  final PayjoinSessions _sessions;

  const WatchPayjoinUsecase(this._sessions);

  /// Publishes updates for one Payjoin session.
  ///
  /// The stream carries its failures as values rather than throwing into
  /// itself, so a watcher failure is switched on like every other pay failure.
  /// A failure also ends the stream, as a thrown error did: there is nothing
  /// further to publish, and the caller decides whether to re-subscribe.
  Stream<Result<PayjoinSession, PayFailure>> execute(String sessionId) async* {
    // The catch keeps the contract airtight. The session store reports its own
    // problems as Err, but a throw from it would reach the subscription as a
    // stream error, and the caller has no arm for that: the watch would die
    // silently and never resubscribe.
    try {
      final current = await _sessions.byId(sessionId);
      switch (current) {
        case Ok(:final value):
          if (value != null) {
            yield Ok(value);
            if (!value.isOngoing) return;
          }
        case Err(:final failure):
          yield Err(PayUnexpectedFailure('Failed to load Payjoin: $failure'));
          return;
      }

      await for (final result in _sessions.watch(sessionIds: {sessionId})) {
        switch (result) {
          case Ok(:final value):
            yield Ok(value);
          case Err(:final failure):
            yield Err(
              PayUnexpectedFailure('Failed to watch Payjoin: $failure'),
            );
            return;
        }
      }
    } catch (e, st) {
      log.severe(
        message: 'The Payjoin session watch threw',
        error: e,
        trace: st,
      );
      yield Err(PayUnexpectedFailure('$e'));
    }
  }
}
