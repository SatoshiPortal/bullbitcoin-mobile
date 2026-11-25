import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';

/// Reads what the virtual IBAN step opens with: the account's virtual IBAN
/// (or none yet) and the owner name it is issued to. Both reads must
/// succeed; a rejected session on either wins over any other failure.
class LoadVirtualIbanContextUsecase {
  final Exchange _exchange;

  const LoadVirtualIbanContextUsecase(this._exchange);

  Future<ExchangeRead<VirtualIbanContext>> execute(
    ExchangeSession session,
  ) async {
    final environment = session.environment;
    final owner = readOfResult(await _exchange.getUserSummary(environment));
    final iban = readOfResult(await _exchange.virtualIbans.find(environment));
    return switch ((owner, iban)) {
      (ReadGot(value: final summary), ReadGot(value: final virtualIban)) =>
        ReadGot(
          VirtualIbanContext(
            virtualIban: virtualIban,
            ownerName:
                '${summary.profile.firstName.trim()} '
                        '${summary.profile.lastName.trim()}'
                    .trim(),
          ),
        ),
      (ReadSessionRejected(:final why), _) ||
      (_, ReadSessionRejected(:final why)) => ReadSessionRejected(why),
      (ReadGot(), final failed) => _failedRead(failed),
      (final failed, _) => _failedRead(failed),
    };
  }
}

ExchangeRead<T> _failedRead<T>(ExchangeRead<Object?> read) => switch (read) {
  ReadMissing() => const ReadMissing(),
  ReadUnreachable(:final reason, :final isNetwork) => ReadUnreachable(
    reason,
    isNetwork: isNetwork,
  ),
  ReadMalformed(:final reason) => ReadMalformed(reason),
  ReadSessionRejected(:final why) => ReadSessionRejected(why),
  ReadGot() => const ReadMalformed('combined read'),
};
