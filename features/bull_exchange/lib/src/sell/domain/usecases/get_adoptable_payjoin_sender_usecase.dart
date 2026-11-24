import 'package:bull_exchange/src/sell/domain/sell_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The persisted Payjoin sender session an order payin may adopt after its
/// start failed, or null (a sender's session id is the order's bip21 URI).
///
/// The engine persists the session — signed original included — BEFORE
/// posting to the directory, and a post failure deliberately keeps the row
/// so the expiry fallback can settle the payment. Whether that row exists is
/// therefore the difference between "this payin is in flight" (adopt and
/// watch it) and "nothing was committed" (safe to re-arm Confirm).
/// [WatchPayjoinUsecase] cannot answer that question — its stream is simply
/// silent for an absent session.
///
/// Only a session that is this payin's is adoptable: an ongoing sender
/// session for the same wallet and amount. A terminal row (completed,
/// aborted or expired) is never replayed by the session stream and would
/// strand the flow on a payin that already settled; a live row for another
/// wallet or amount is an earlier attempt on the same link. "No session" and
/// "could not tell" stay distinguishable: an unreadable store is a failure.
class GetAdoptablePayjoinSenderUsecase {
  final PayjoinSessions _sessions;

  const GetAdoptablePayjoinSenderUsecase(this._sessions);

  @useResult
  Future<Result<PayjoinSenderSession?, SellFailure>> execute({
    required String sessionId,
    required String walletId,
    required int amountSat,
    String? expectedOriginalTxId,
  }) async {
    switch (await _sessions.byId(sessionId)) {
      case Ok(:final value):
        if (value is! PayjoinSenderSession ||
            !value.isOngoing ||
            value.walletId != walletId ||
            value.amountSat != amountSat ||
            (expectedOriginalTxId != null &&
                value.originalTxId != expectedOriginalTxId)) {
          return const Ok(null);
        }
        return Ok(value);
      case Err(:final failure):
        log.warning(
          'Could not read the Payjoin session',
          error: '${failure.runtimeType}: ${failure.logMessage ?? "-"}',
        );
        return Err(SellUnexpectedFailure(failure.logMessage));
    }
  }
}
