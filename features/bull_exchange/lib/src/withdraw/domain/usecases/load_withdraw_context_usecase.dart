import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:bull_exchange/src/withdraw/domain/withdraw_flow.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Reads what the withdraw flow opens with: the session account's summary
/// and the open journal entries.
class LoadWithdrawContextUsecase {
  final Exchange _exchange;

  const LoadWithdrawContextUsecase(this._exchange);

  Future<Result<WithdrawContext, ExchangeReadFailure>> execute(
    ExchangeSession session,
  ) async {
    final summary = readOfResult(
      await _exchange.getUserSummary(session.environment),
    );
    // A journal that can't be read leaves no entry to start from; the
    // write gate then refuses the confirm itself (JournalUnreadable).
    final entries = switch (await _exchange.openUnknownWrites(session)) {
      Ok(:final value) => value,
      Err() => const <UnknownWrite>[],
    };
    return switch (summary) {
      Ok(:final value) => Ok(WithdrawContext(value, entries)),
      Err(failure: ExchangeMissingFailure()) => const Err(
        ExchangeMissingFailure(),
      ),
      Err(
        failure: ExchangeUnreachableFailure(:final reason, :final isNetwork),
      ) =>
        Err(ExchangeUnreachableFailure(reason, isNetwork: isNetwork)),
      Err(failure: ExchangeSessionRejectedFailure(:final why)) => Err(
        ExchangeSessionRejectedFailure(why),
      ),
      Err(failure: ExchangeMalformedFailure(:final reason)) => Err(
        ExchangeMalformedFailure(reason),
      ),
    };
  }
}
