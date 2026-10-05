import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';

class GetPayjoinByTxIdUsecase {
  final PayjoinSessions _sessions;

  const GetPayjoinByTxIdUsecase(this._sessions);

  @useResult
  Future<Result<PayjoinSession, TransactionFailure>> execute(
    String transactionId,
  ) async {
    return switch (await _sessions.byTransactionId(transactionId)) {
      Ok(value: [final session, ...]) => Ok(session),
      Ok() => const Err(TransactionNotFoundFailure('payjoin not found')),
      Err(:final failure) => Err(
        TransactionUnexpectedFailure(
          'byTransactionId failed: ${failure.runtimeType}',
        ),
      ),
    };
  }
}
