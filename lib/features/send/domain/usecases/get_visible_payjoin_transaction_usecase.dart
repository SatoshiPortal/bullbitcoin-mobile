import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

/// The transaction of a Payjoin session that the network already knows, or
/// null when none is visible.
///
/// Exists for the Send expired-session path: `expired` only means the engine
/// recorded no broadcast outcome and released the inputs. The receiver holds
/// a signed original it may broadcast on its own, and a lagging sync can hide
/// a fallback that did reach the network; either pays the payee, and offering
/// Confirm again on top of it would pay a second time on other coins. A
/// failed check returns null and the caller re-arms as before: it cannot
/// settle on a txid it could not see.
class GetVisiblePayjoinTransactionUsecase {
  final PayjoinSessions _sessions;

  const GetVisiblePayjoinTransactionUsecase(this._sessions);

  Future<String?> execute(String sessionId) async {
    switch (await _sessions.visibleTransaction(sessionId)) {
      case Ok(:final value):
        return value;
      case Err(:final failure):
        log.warning(
          'Could not check the Payjoin transaction visibility',
          error: '${failure.runtimeType}: ${failure.logMessage ?? "-"}',
        );
        return null;
    }
  }
}
