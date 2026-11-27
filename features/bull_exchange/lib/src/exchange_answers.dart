import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// The read result of an exchange call that answers the whole
/// `Result<T, ExchangeFailure>`: its failure narrowed to an
/// [ExchangeReadFailure]. A failure is never read as a value.
Result<T, ExchangeReadFailure> readOfResult<T>(
  Result<T, ExchangeFailure> result,
) => switch (result) {
  Ok(:final value) => Ok(value),
  Err(:final failure) => readOfExchangeFailure(failure),
};

Result<T, ExchangeReadFailure> readOfExchangeFailure<T>(
  ExchangeFailure failure,
) => switch (failure) {
  final ExchangeReadFailure read => Err(read),
  ExchangeNotAuthenticatedFailure() => const Err(
    ExchangeSessionRejectedFailure(ExchangeSessionRejection.signedOut),
  ),
  ExchangeCredentialReadFailure() => const Err(
    ExchangeSessionRejectedFailure(
      ExchangeSessionRejection.credentialUnavailable,
    ),
  ),
  ExchangeNetworkFailure() => Err(
    ExchangeUnreachableFailure(failure.runtimeType.toString(), isNetwork: true),
  ),
  _ => Err(
    ExchangeUnreachableFailure(
      failure.runtimeType.toString(),
      isNetwork: false,
    ),
  ),
};

/// The write result of an exchange write that answers the whole
/// `Result<T, ExchangeFailure>`: its failure narrowed to an
/// [ExchangeWriteFailure]. Only a failure that proves the write never
/// left the app is NotSent, and only a server refusal is Refused: everything
/// else may have reached the exchange and is OutcomeUnknown, so the step
/// re-reads instead of writing again.
Result<T, ExchangeWriteFailure> writeOfResult<T>(
  Result<T, ExchangeFailure> result,
) => switch (result) {
  Ok(:final value) => Ok(value),
  Err(:final failure) => switch (failure) {
    final ExchangeWriteFailure write => Err(write),
    ExchangeNotAuthenticatedFailure() => const Err(
      ExchangeWriteNotSentFailure(ExchangeNotSentReason.signedOut),
    ),
    ExchangeCredentialReadFailure() => const Err(
      ExchangeWriteNotSentFailure(ExchangeNotSentReason.credentialUnavailable),
    ),
    ExchangeOperationStaleFailure() => const Err(
      ExchangeWriteNotSentFailure(ExchangeNotSentReason.sessionChanged),
    ),
    ExchangeOrderRejectedFailure(:final apiCode, :final rpcCode) => Err(
      ExchangeWriteRefusedFailure(
        ExchangeRefusal(apiCode: apiCode, rpcCode: rpcCode),
      ),
    ),
    ExchangeVirtualIbanNotAvailableFailure() ||
    ExchangeEuResidencyRequiredFailure() ||
    ExchangeVirtualIbanNotAvailableFailure() ||
    ExchangeEuResidencyRequiredFailure() => const Err(
      ExchangeWriteRefusedFailure(ExchangeRefusal()),
    ),
    _ => Err(
      ExchangeWriteOutcomeUnknownFailure(failure.runtimeType.toString()),
    ),
  },
};
