import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

/// Settles a Payjoin session with its original transaction now.
///
/// Used after adopting a session whose start failed: the directory most
/// likely never received the original, the stored row cannot pick up a
/// proposal, and left alone the engine would only send the original at the
/// session deadline. The engine keeps its own guards (a visible competing
/// transaction, the spend gate), so a refusal is not an error here: the
/// session stays armed and settles at the deadline as before. A wallet that
/// is only busy with a sync is asked again a few times before giving up.
/// Returns the settled session, or null when the broadcast was refused: the
/// engine publishes the same settlement on the session stream, and the
/// value lets a caller that subscribed after the fact settle on it too.
class BroadcastPayjoinOriginalUsecase {
  static const busyRetries = 5;
  static const busyRetryDelay = Duration(seconds: 3);

  final PayjoinSender _sender;
  final Future<void> Function(Duration) _wait;

  const BroadcastPayjoinOriginalUsecase(this._sender, [this._wait = _delay]);

  static Future<void> _delay(Duration duration) =>
      Future<void>.delayed(duration);

  Future<PayjoinSenderSession?> execute(String sessionId) async {
    for (var attempt = 0; ; attempt++) {
      switch (await _sender.broadcastOriginal(sessionId)) {
        case Ok(value: final PayjoinSenderSession settled):
          return settled;
        case Ok():
          return null;
        case Err(failure: PayjoinSpendBlockedFailure(busy: true))
            when attempt < busyRetries:
          await _wait(busyRetryDelay);
        case Err(:final failure):
          log.warning(
            'Sell Payjoin original not sent after the failed start; the '
            'session settles at its deadline',
            error: '${failure.runtimeType}: ${failure.logMessage ?? "-"}',
          );
          return null;
      }
    }
  }
}
