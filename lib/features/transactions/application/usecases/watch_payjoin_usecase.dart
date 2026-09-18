import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:bull_payjoin/bull_payjoin.dart';

class WatchPayjoinUsecase {
  final PayjoinSessions _sessions;

  const WatchPayjoinUsecase(this._sessions);

  /// Emits a `Result` per event rather than throwing, so a watcher failure is
  /// a value the cubit can switch on like any other.
  ///
  /// The `await for` covers both ways the session stream can fail: a throw on
  /// subscribe, and an error event pushed into the stream later (a database
  /// watch dropping out). Mapping alone would let the latter escape as an
  /// unhandled zone error, since the cubit has no `onError`.
  Stream<Result<PayjoinSession, TransactionFailure>> execute({
    List<String>? ids,
  }) async* {
    try {
      await for (final result in _sessions.watch(sessionIds: ids?.toSet())) {
        yield switch (result) {
          Ok(:final value) => Ok<PayjoinSession, TransactionFailure>(value),
          Err(:final failure) => Err<PayjoinSession, TransactionFailure>(
            TransactionUnexpectedFailure(
              'watch payjoin failed: ${failure.runtimeType}',
            ),
          ),
        };
      }
    } catch (e) {
      yield Err(
        TransactionUnexpectedFailure('watch payjoin failed: ${e.runtimeType}'),
      );
    }
  }
}
