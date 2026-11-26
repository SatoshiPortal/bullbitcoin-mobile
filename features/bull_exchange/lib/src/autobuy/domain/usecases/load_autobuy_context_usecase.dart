import 'package:bull_exchange/src/account/domain/usecases/get_user_summary_usecase.dart';
import 'package:bull_exchange/src/autobuy/domain/autobuy_flow.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Reads what the AutoBuy flow opens with (and re-reads after KYC): the
/// session account's summary and the open journal entries.
class LoadAutoBuyContextUsecase {
  final Exchange _exchange;
  final GetUserSummaryUsecase _getUserSummary;

  const LoadAutoBuyContextUsecase(this._exchange, this._getUserSummary);

  Future<ExchangeRead<AutoBuyContext>> execute(ExchangeSession session) async {
    // One after the other: a record `.wait` would wrap a programmer error
    // of either read in a ParallelWaitError instead of rethrowing it.
    final read = await _getUserSummary.execute(session);
    final entries = await _exchange.openUnknownWrites();
    // A journal that can't be read leaves no entry to start from; the
    // write gate then refuses the write itself (JournalUnreadable).
    final open = switch (entries) {
      Ok(:final value) => value,
      Err() => const <UnknownWrite>[],
    };
    return switch (read) {
      ReadGot(:final value) => ReadGot(AutoBuyContext(value, open)),
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
