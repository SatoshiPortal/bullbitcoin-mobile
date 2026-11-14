import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

/// The transaction of a Payjoin session that the network already knows, or
/// null when none is visible.
///
/// Exists for the Pay expired-session path: `expired` only means the engine
/// recorded no broadcast outcome. A fallback broadcast that threw after the
/// transaction reached the network, or that landed but failed its
/// bookkeeping, still pays the order; re-arming Confirm on top of it would
/// pay the order a second time on the inputs the expiry released. A failed
/// check returns null and the caller re-arms as before: it cannot latch a
/// txid it could not see.
class GetVisiblePayjoinTransactionUsecase {
  final PayjoinSessions _sessions;

  const GetVisiblePayjoinTransactionUsecase(this._sessions);

  Future<String?> execute(String sessionId) async {
    final result = await _sessions.visibleTransaction(sessionId);
    return switch (result) {
      Ok(:final value) => value,
      Err() => null,
    };
  }
}
