import 'package:bb_mobile/core/utils/result.dart' as core;
import 'package:bb_mobile/features/send/domain/send_failure.dart';
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
    // The stream only carries changes: a session that settled before this
    // subscription (e.g. its original was broadcast while starting) would
    // otherwise never be delivered.
    for (final id in ids ?? const <String>[]) {
      if (await _sessions.byId(id) case Ok(value: final session?)) {
        yield core.Ok(session);
      }
    }
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
