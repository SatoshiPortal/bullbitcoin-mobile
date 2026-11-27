import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Whether the source wallet or its network shows [txid], read through the
/// payjoin session that carries it; [ExchangeTransactionLookupFailure] when
/// it can't tell (no such session, or a failed read).
class CheckTransactionSeenUsecase {
  final PayjoinSessions _payjoinSessions;

  const CheckTransactionSeenUsecase(this._payjoinSessions);

  Future<Result<bool, ExchangeTransactionLookupFailure>> execute(
    String txid,
  ) async {
    switch (await _payjoinSessions.byTransactionId(txid)) {
      case Ok(value: [final session, ...]):
        return switch (await _payjoinSessions.visibleTransaction(session.id)) {
          Ok(:final value) => Ok(value != null),
          Err() => const Err(
            ExchangeTransactionLookupFailure('visible transaction unreadable'),
          ),
        };
      case Ok():
        return const Err(
          ExchangeTransactionLookupFailure('no payjoin session carries it'),
        );
      case Err():
        return const Err(
          ExchangeTransactionLookupFailure('payjoin sessions unreadable'),
        );
    }
  }
}
