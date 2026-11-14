import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The transaction of a Payjoin session that the network already knows, or
/// null when none is visible.
///
/// Exists for the Sell expired-session path: `expired` only means the engine
/// recorded no broadcast outcome. A fallback broadcast that threw after the
/// transaction reached the network, or that landed but failed its
/// bookkeeping, still pays the order; re-arming Confirm on top of it would
/// pay the order a second time on the inputs the expiry released. On a
/// failed check the caller re-arms as before: it cannot latch a txid it
/// could not see.
class GetVisiblePayjoinTransactionUsecase {
  final PayjoinSessions _sessions;

  const GetVisiblePayjoinTransactionUsecase(this._sessions);

  @useResult
  Future<Result<String?, SellFailure>> execute(String sessionId) async {
    switch (await _sessions.visibleTransaction(sessionId)) {
      case Ok(:final value):
        return Ok(value);
      case Err(:final failure):
        log.warning(
          'Could not check the Payjoin transaction visibility',
          error: '${failure.runtimeType}: ${failure.logMessage ?? "-"}',
        );
        return Err(SellUnexpectedFailure(failure.logMessage));
    }
  }
}
