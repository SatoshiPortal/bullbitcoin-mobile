import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

/// Whether the source wallet or its network shows [txid], read through the
/// payjoin session that carries it; null when it can't tell (no such
/// session, or a failed read).
class CheckTransactionSeenUsecase {
  final PayjoinSessions _payjoinSessions;

  const CheckTransactionSeenUsecase(this._payjoinSessions);

  Future<bool?> execute(String txid) async {
    switch (await _payjoinSessions.byTransactionId(txid)) {
      case Ok(value: [final session, ...]):
        return switch (await _payjoinSessions.visibleTransaction(session.id)) {
          Ok(:final value) => value != null,
          Err() => null,
        };
      case Ok() || Err():
        return null;
    }
  }
}
