import 'package:bull_exchange/src/dca/domain/dca_flow.dart';
import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Reads what the DCA flow opens with (and re-reads after a detour): the
/// session account's summary, the exchange default wallets and the open
/// journal entries. A session rejection in either read wins, then an
/// unreachable one, then a malformed one, then a missing one.
class LoadDcaContextUsecase {
  final Exchange _exchange;

  const LoadDcaContextUsecase(this._exchange);

  Future<ExchangeRead<DcaContext>> execute(ExchangeSession session) async {
    final summary = readOfResult(
      await _exchange.getUserSummary(session.environment),
    );
    final wallets = readOfResult(await _exchange.getDefaultWallets());
    // A journal that can't be read leaves no entry to start from; the
    // write gate then refuses the create itself (JournalUnreadable).
    final entries = switch (await _exchange.openUnknownWrites(session)) {
      Ok(:final value) => value,
      Err() => const <UnknownWrite>[],
    };
    return switch ((summary, wallets)) {
      (ReadGot(value: final summary), ReadGot(value: final wallets)) => ReadGot(
        DcaContext(
          summary: summary,
          defaultWallets: wallets,
          openEntries: entries,
        ),
      ),
      (ReadSessionRejected(:final why), _) ||
      (_, ReadSessionRejected(:final why)) => ReadSessionRejected(why),
      (ReadUnreachable(:final reason, :final isNetwork), _) ||
      (
        _,
        ReadUnreachable(:final reason, :final isNetwork),
      ) => ReadUnreachable(reason, isNetwork: isNetwork),
      (ReadMalformed(:final reason), _) ||
      (_, ReadMalformed(:final reason)) => ReadMalformed(reason),
      (ReadMissing(), _) || (_, ReadMissing()) => const ReadMissing(),
    };
  }
}
