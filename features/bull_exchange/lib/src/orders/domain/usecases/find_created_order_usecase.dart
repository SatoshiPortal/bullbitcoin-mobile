import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// After a create whose outcome is unknown: looks for the order the create
/// made among the account's orders of the journaled type, created around
/// [sentAt]. [ExchangeMissingFailure] when none matches or the match is not an [O].
class FindCreatedOrderUsecase {
  final Exchange _exchange;

  const FindCreatedOrderUsecase(this._exchange);

  Future<Result<O, ExchangeReadFailure>> execute<O extends Order>(
    ExchangeSession session,
    OrderCreateJournalRequest journal,
    DateTime sentAt,
  ) async => switch (await _exchange
      .orders(session.environment)
      .getOrders(type: journal.type)) {
    Ok(:final value) => switch (findCreatedOrder(journal, sentAt, value)) {
      final O order => Ok(order),
      _ => const Err(ExchangeMissingFailure()),
    },
    Err(:final failure) => readOfExchangeFailure(failure),
  };
}
