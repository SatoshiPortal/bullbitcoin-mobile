import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:bull_exchange/src/pay/domain/pay_flow.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Reads what the pay flow opens with (and re-reads after a detour): the
/// session account's summary and the open journal entries.
class LoadPayContextUsecase {
  final Exchange _exchange;

  const LoadPayContextUsecase(this._exchange);

  Future<ExchangeRead<PayContext>> execute(ExchangeSession session) async {
    final summary = readOfResult(
      await _exchange.getUserSummary(session.environment),
    );
    final entries = switch (await _exchange.openUnknownWrites()) {
      Ok(:final value) => value,
      Err() => const <UnknownWrite>[],
    };
    return switch (summary) {
      ReadGot(:final value) => ReadGot(PayContext(value, entries)),
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
