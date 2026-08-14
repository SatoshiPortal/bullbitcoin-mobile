import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

/// Discrete lookup of a persisted Payjoin session by its id (a sender's id
/// is the payment's bip21 URI).
///
/// Exists for the payjoin-start failure path: the engine persists the
/// session — signed original included — BEFORE posting to the directory,
/// and a post failure deliberately keeps the row so the expiry fallback can
/// settle the payment. Whether that row exists is therefore the difference
/// between "this payment is in flight and will be broadcast at the deadline"
/// (adopt and watch it) and "nothing was committed" (safe to re-arm
/// Confirm). [WatchPayjoinUsecase] cannot answer that question — its stream
/// is simply silent for an absent session.
class GetPayjoinUsecase {
  final PayjoinSessions _sessions;

  const GetPayjoinUsecase(this._sessions);

  /// Returns the persisted session, or null when none exists. A storage
  /// read failure also returns null: the caller falls back to the plain
  /// error path, where any retry is fail-closed anyway — with payjoin
  /// storage unreadable, coin selection refuses to build a transaction at
  /// all rather than risk double-spending reserved inputs.
  Future<PayjoinSession?> execute(String sessionId) async {
    final result = await _sessions.byId(sessionId);
    return switch (result) {
      Ok(:final value) => value,
      Err() => null,
    };
  }
}
