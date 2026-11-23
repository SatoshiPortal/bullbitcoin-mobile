import 'package:primitives/primitives.dart' as core;
import 'package:send/send.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class WatchPayjoinUsecase {
  final PayjoinSessions _sessions;

  const WatchPayjoinUsecase(this._sessions);

  @useResult
  Stream<core.Result<PayjoinSession, SendFailure>> execute({
    List<String>? ids,
  }) async* {
    // Seeded with the stored rows: the stream never replays a terminal row,
    // and an update between the caller's own read and this subscription
    // would otherwise be lost. A watch of terminal rows only ends here.
    var pending = false;
    for (final id in ids ?? const <String>[]) {
      switch (await _sessions.byId(id)) {
        case Ok(value: final PayjoinSession session):
          yield core.Ok(session);
          pending = pending || session.isOngoing;
        case Ok():
          pending = true;
        case Err(:final failure):
          pending = true;
          log.warning(
            'Failed to read the Payjoin session',
            error: '${failure.runtimeType}: ${failure.logMessage ?? "-"}',
          );
          yield core.Err(
            SendTransactionConfirmationFailure(
              logMessage: failure.logMessage ?? 'Failed to read Payjoin',
            ),
          );
      }
    }
    if (ids != null && ids.isNotEmpty && !pending) return;
    await for (final result in _sessions.watch(sessionIds: ids?.toSet())) {
      switch (result) {
        case Ok(:final value):
          yield core.Ok(value);
        case Err(:final failure):
          log.warning(
            'Failed to watch Payjoin session',
            error: '${failure.runtimeType}: ${failure.logMessage ?? "-"}',
          );
          yield core.Err(
            SendTransactionConfirmationFailure(
              logMessage: failure.logMessage ?? 'Failed to watch Payjoin',
            ),
          );
      }
    }
  }
}
