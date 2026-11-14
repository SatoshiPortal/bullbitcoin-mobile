import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

/// The persisted Payjoin sender session a payment may adopt after its start
/// failed, or null (a sender's session id is the payment's bip21 URI).
///
/// The engine persists the session — signed original included — BEFORE
/// posting to the directory, and a post failure deliberately keeps the row
/// so the expiry fallback can settle the payment. Whether that row exists is
/// therefore the difference between "this payment is in flight and will be
/// broadcast at the deadline" (adopt and watch it) and "nothing was
/// committed" (safe to re-arm Confirm). [WatchPayjoinUsecase] cannot answer
/// that question — its stream is simply silent for an absent session.
///
/// Only a session that is this payment's is adoptable: an ongoing sender
/// session for the same wallet and amount. A terminal row (completed,
/// aborted or expired) is never replayed by the session stream and would
/// strand the flow; a live row for another wallet or amount belongs to an
/// earlier payment on the same link and would report this amount as sent.
class GetAdoptablePayjoinSenderUsecase {
  final PayjoinSessions _sessions;

  const GetAdoptablePayjoinSenderUsecase(this._sessions);

  /// A storage read failure also returns null: the caller falls back to the
  /// plain error path, where any retry is fail-closed anyway — with payjoin
  /// storage unreadable, coin selection refuses to build a transaction at
  /// all rather than risk double-spending reserved inputs.
  Future<PayjoinSenderSession?> execute({
    required String sessionId,
    required String walletId,
    required int? amountSat,
  }) async {
    final result = await _sessions.byId(sessionId);
    final session = switch (result) {
      Ok(:final value) => value,
      Err() => null,
    };
    if (session is! PayjoinSenderSession ||
        !session.isOngoing ||
        session.walletId != walletId ||
        session.amountSat != amountSat) {
      return null;
    }
    return session;
  }
}
