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
    await for (final result in _sessions.watch(sessionIds: ids?.toSet())) {
      switch (result) {
        case Ok(:final value):
          yield core.Ok(value);
        case Err(:final failure):
          log.warning(
            'Failed to watch Payjoin session',
            error: failure.logMessage ?? failure.runtimeType.toString(),
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
