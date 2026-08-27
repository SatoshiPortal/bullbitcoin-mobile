import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

class GetPayjoinByIdUsecase {
  final PayjoinSessions _sessions;

  const GetPayjoinByIdUsecase(this._sessions);

  Future<PayjoinSession> execute(String payjoinId) async {
    final result = await _sessions.byId(payjoinId);
    return switch (result) {
      Ok(value: final session?) => session,
      Ok() => throw GetPayjoinByIdException('Payjoin not found'),
      Err() => throw GetPayjoinByIdException('Failed to load Payjoin'),
    };
  }
}

class GetPayjoinByIdException extends BullException {
  GetPayjoinByIdException(super.message);
}
