import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:primitives/primitives.dart';

/// Reads what the virtual IBAN step opens with: the account's virtual IBAN
/// (or none yet) and the owner name it is issued to. Both reads must
/// succeed; a rejected session on either wins over any other failure.
class LoadVirtualIbanContextUsecase {
  final Exchange _exchange;

  const LoadVirtualIbanContextUsecase(this._exchange);

  Future<Result<VirtualIbanContext, ExchangeReadFailure>> execute(
    ExchangeSession session,
  ) async {
    final environment = session.environment;
    final owner = readOfResult(await _exchange.getUserSummary(environment));
    final iban = readOfResult(await _exchange.virtualIbans.find(environment));
    return switch ((owner, iban)) {
      (Ok(value: final summary), Ok(value: final virtualIban)) => Ok(
        VirtualIbanContext(
          virtualIban: virtualIban,
          ownerName:
              '${summary.profile.firstName.trim()} '
                      '${summary.profile.lastName.trim()}'
                  .trim(),
        ),
      ),
      (Err(failure: ExchangeSessionRejectedFailure(:final why)), _) ||
      (
        _,
        Err(failure: ExchangeSessionRejectedFailure(:final why)),
      ) => Err(ExchangeSessionRejectedFailure(why)),
      (Ok(), final failed) => _failedRead(failed),
      (final failed, _) => _failedRead(failed),
    };
  }
}

Result<T, ExchangeReadFailure> _failedRead<T>(
  Result<Object?, ExchangeReadFailure> read,
) => switch (read) {
  Err(failure: ExchangeMissingFailure()) => const Err(ExchangeMissingFailure()),
  Err(failure: ExchangeUnreachableFailure(:final reason, :final isNetwork)) =>
    Err(ExchangeUnreachableFailure(reason, isNetwork: isNetwork)),
  Err(failure: ExchangeMalformedFailure(:final reason)) => Err(
    ExchangeMalformedFailure(reason),
  ),
  Err(failure: ExchangeSessionRejectedFailure(:final why)) => Err(
    ExchangeSessionRejectedFailure(why),
  ),
  Ok() => const Err(ExchangeMalformedFailure('combined read')),
};
