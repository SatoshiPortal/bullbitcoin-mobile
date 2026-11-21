import 'dart:async';

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
    // Subscribed before reading the current state, so an update emitted
    // during that read is buffered rather than dropped.
    final updates = StreamController<Result<PayjoinSession, PayjoinFailure>>();
    final subscription = _sessions
        .watch(sessionIds: ids?.toSet())
        .listen(updates.add, onError: updates.addError, onDone: updates.close);
    try {
      // The stream only carries changes: a session that settled before this
      // subscription (e.g. its original was broadcast while starting) would
      // otherwise never be delivered.
      var settled = ids != null && ids.isNotEmpty;
      for (final id in ids ?? const <String>[]) {
        switch (await _sessions.byId(id)) {
          case Ok(:final value):
            if (value != null) yield core.Ok(value);
            if (value == null || value.isOngoing) settled = false;
          case Err(:final failure):
            settled = false;
            yield core.Err(
              _sanitized('Failed to load Payjoin session', failure),
            );
        }
      }
      if (settled) return;

      await for (final result in updates.stream) {
        switch (result) {
          case Ok(:final value):
            yield core.Ok(value);
          case Err(:final failure):
            yield core.Err(
              _sanitized('Failed to watch Payjoin session', failure),
            );
        }
      }
    } finally {
      await subscription.cancel();
    }
  }

  SendFailure _sanitized(String context, PayjoinFailure failure) {
    log.warning(
      context,
      error: '${failure.runtimeType}: ${failure.logMessage ?? "-"}',
    );
    return SendTransactionConfirmationFailure(
      logMessage: failure.logMessage ?? context,
    );
  }
}
