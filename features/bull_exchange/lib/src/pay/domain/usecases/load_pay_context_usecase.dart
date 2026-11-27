import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:bull_exchange/src/pay/domain/pay_flow.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// Reads what the pay flow opens with (and re-reads after a detour): the
/// session account's summary and the open journal entries.
class LoadPayContextUsecase {
  final Exchange _exchange;

  const LoadPayContextUsecase(this._exchange);

  Future<Result<PayContext, ExchangeReadFailure>> execute(
    ExchangeSession session,
  ) async {
    final summary = readOfResult(
      await _exchange.getUserSummary(session.environment),
    );
    final entries = switch (await _exchange.openUnknownWrites(session)) {
      Ok(:final value) => value,
      Err() => const <UnknownWrite>[],
    };
    return switch (summary) {
      Ok(:final value) => Ok(PayContext(value, entries)),
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
