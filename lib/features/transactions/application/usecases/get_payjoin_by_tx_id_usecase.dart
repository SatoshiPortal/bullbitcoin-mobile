import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

class GetPayjoinByTxIdUsecase {
  final PayjoinSessions _sessions;

  const GetPayjoinByTxIdUsecase(this._sessions);

  Future<PayjoinSession> execute(String transactionId) async {
    final result = await _sessions.byTransactionId(transactionId);
    return switch (result) {
      Ok(value: [final session, ...]) => session,
      Ok() => throw GetPayjoinByTxIdException('Payjoin not found'),
      Err() => throw GetPayjoinByTxIdException('Failed to load Payjoin'),
    };
  }
}

class GetPayjoinByTxIdException extends BullException {
  GetPayjoinByTxIdException(super.message);
}
