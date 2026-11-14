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
/// session stays armed and settles at the deadline as before. Returns
/// whether the broadcast was accepted.
class BroadcastPayjoinOriginalUsecase {
  final PayjoinSender _sender;

  const BroadcastPayjoinOriginalUsecase(this._sender);

  Future<bool> execute(String sessionId) async {
    switch (await _sender.broadcastOriginal(sessionId)) {
      case Ok():
        return true;
      case Err(:final failure):
        log.warning(
          'Send Payjoin original not sent after the failed start; the '
          'session settles at its deadline',
          error: '${failure.runtimeType}: ${failure.logMessage ?? "-"}',
        );
        return false;
    }
  }
}
