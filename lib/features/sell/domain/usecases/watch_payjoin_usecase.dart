import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class WatchPayjoinUsecase {
  final PayjoinSessions _sessions;

  const WatchPayjoinUsecase(this._sessions);

  @useResult
  Stream<Result<PayjoinSession, SellFailure>> execute(String sessionId) async* {
    final current = await _sessions.byId(sessionId);
    switch (current) {
      case Ok(:final value):
        if (value != null) {
          yield Ok(value);
          if (!value.isOngoing) return;
        }
      case Err(:final failure):
        yield Err(_sanitized('Failed to load Payjoin', failure));
        return;
    }

    await for (final result in _sessions.watch(sessionIds: {sessionId})) {
      switch (result) {
        case Ok(:final value):
          yield Ok(value);
        case Err(:final failure):
          yield Err(_sanitized('Failed to watch Payjoin', failure));
      }
    }
  }

  SellFailure _sanitized(String context, PayjoinFailure failure) {
    log.warning(
      context,
      error: '${failure.runtimeType}: ${failure.logMessage ?? "-"}',
    );
    return SellUnexpectedFailure(failure.logMessage ?? context);
  }
}
