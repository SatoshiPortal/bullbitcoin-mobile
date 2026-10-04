import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';
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

  @useResult
  Future<Result<PayjoinSession?, SellFailure>> execute(String sessionId) async {
    switch (await _sessions.byId(sessionId)) {
      case Ok(:final value):
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
