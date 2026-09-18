import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';

class GetPayjoinByIdUsecase {
  final PayjoinSessions _sessions;

  const GetPayjoinByIdUsecase(this._sessions);

  @useResult
  Future<Result<PayjoinSession, TransactionFailure>> execute(
    String payjoinId,
  ) async {
    return switch (await _sessions.byId(payjoinId)) {
      Ok(value: final session?) => Ok(session),
      Ok() => const Err(TransactionNotFoundFailure('payjoin not found')),
      Err(:final failure) => Err(
        TransactionUnexpectedFailure('byId failed: ${failure.runtimeType}'),
      ),
    };
  }
}
