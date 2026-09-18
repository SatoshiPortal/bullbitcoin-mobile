import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:bull_payjoin/bull_payjoin.dart';

class WatchPayjoinUsecase {
  final PayjoinSessions _sessions;

  const WatchPayjoinUsecase(this._sessions);

  /// Emits a `Result` per event rather than throwing, so a watcher failure is
  /// a value the cubit can switch on like any other.
  Stream<Result<PayjoinSession, TransactionFailure>> execute({
    List<String>? ids,
  }) {
    return _sessions.watch(sessionIds: ids?.toSet()).map((result) {
      return switch (result) {
        Ok(:final value) => Ok<PayjoinSession, TransactionFailure>(value),
        Err(:final failure) => Err<PayjoinSession, TransactionFailure>(
          TransactionUnexpectedFailure(
            'watch payjoin failed: ${failure.runtimeType}',
          ),
        ),
      };
    });
  }
}
