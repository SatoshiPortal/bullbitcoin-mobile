import 'package:bull_exchange/src/dca/domain/dca_state.dart';
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

  Future<Result<DcaContext, ExchangeReadFailure>> execute(
    ExchangeSession session,
  ) async {
    final summary = readOfResult(
      await _exchange.getUserSummary(session.environment),
    );
    final wallets = await _exchange.readDefaultWallets(session);
    // A journal that can't be read leaves no entry to start from; the
    // write gate then refuses the create itself (JournalUnreadable).
    final entries = switch (await _exchange.openUnknownWrites(session)) {
      Ok(:final value) => value,
      Err() => const <UnknownWrite>[],
    };
    return switch ((summary, wallets)) {
      (Ok(value: final summary), Ok(value: final wallets)) => Ok(
        DcaContext(
          summary: summary,
          defaultWallets: wallets,
          openEntries: entries,
        ),
      ),
      (Err(failure: ExchangeSessionRejectedFailure(:final why)), _) ||
      (
        _,
        Err(failure: ExchangeSessionRejectedFailure(:final why)),
      ) => Err(ExchangeSessionRejectedFailure(why)),
      (
        Err(
          failure: ExchangeUnreachableFailure(:final reason, :final isNetwork),
        ),
        _,
      ) ||
      (
        _,
        Err(
          failure: ExchangeUnreachableFailure(:final reason, :final isNetwork),
        ),
      ) => Err(ExchangeUnreachableFailure(reason, isNetwork: isNetwork)),
      (Err(failure: ExchangeMalformedFailure(:final reason)), _) ||
      (
        _,
        Err(failure: ExchangeMalformedFailure(:final reason)),
      ) => Err(ExchangeMalformedFailure(reason)),
      (Err(failure: ExchangeMissingFailure()), _) ||
      (
        _,
        Err(failure: ExchangeMissingFailure()),
      ) => const Err(ExchangeMissingFailure()),
    };
  }
}
