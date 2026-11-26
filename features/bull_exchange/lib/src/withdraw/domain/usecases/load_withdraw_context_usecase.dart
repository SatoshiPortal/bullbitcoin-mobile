import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:bull_exchange/src/withdraw/domain/withdraw_flow.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Reads what the withdraw flow opens with: the session account's summary
/// and the open journal entries.
class LoadWithdrawContextUsecase {
  final Exchange _exchange;

  const LoadWithdrawContextUsecase(this._exchange);

  Future<ExchangeRead<WithdrawContext>> execute(ExchangeSession session) async {
    final summary = readOfResult(
      await _exchange.getUserSummary(session.environment),
    );
    // A journal that can't be read leaves no entry to start from; the
    // write gate then refuses the confirm itself (JournalUnreadable).
    final entries = switch (await _exchange.openUnknownWrites()) {
      Ok(:final value) => value,
      Err() => const <UnknownWrite>[],
    };
    return switch (summary) {
      ReadGot(:final value) => ReadGot(WithdrawContext(value, entries)),
      ReadMissing() => const ReadMissing(),
      ReadUnreachable(:final reason, :final isNetwork) => ReadUnreachable(
        reason,
        isNetwork: isNetwork,
      ),
      ReadSessionRejected(:final why) => ReadSessionRejected(why),
      ReadMalformed(:final reason) => ReadMalformed(reason),
    };
  }
}
