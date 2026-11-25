import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// The closed read result of an exchange call that still answers
/// `Result<T, ExchangeFailure>`. A failure is never read as a value.
ExchangeRead<T> readOfResult<T>(Result<T, ExchangeFailure> result) =>
    switch (result) {
      Ok(:final value) => ReadGot(value),
      Err(:final failure) => readOfExchangeFailure(failure),
    };

ExchangeRead<T> readOfExchangeFailure<T>(ExchangeFailure failure) =>
    switch (failure) {
      ExchangeNotAuthenticatedFailure() ||
      RecipientsNotAuthenticatedFailure() => const ReadSessionRejected(
        ExchangeSessionRejection.signedOut,
      ),
      ExchangeCredentialReadFailure() => const ReadSessionRejected(
        ExchangeSessionRejection.credentialUnavailable,
      ),
      ExchangeSessionRejectedFailure() => const ReadSessionRejected(
        ExchangeSessionRejection.server,
      ),
      ExchangeNetworkFailure() || RecipientsNetworkFailure() => ReadUnreachable(
        failure.runtimeType.toString(),
        isNetwork: true,
      ),
      _ => ReadUnreachable(failure.runtimeType.toString(), isNetwork: false),
    };

/// The closed write result of an exchange write that still answers
/// `Result<T, ExchangeFailure>`. Only a failure that proves the write never
/// left the app is NotSent, and only a server refusal is Refused: everything
/// else may have reached the exchange and is OutcomeUnknown, so the step
/// re-reads instead of writing again.
ExchangeWrite<T> writeOfResult<T>(Result<T, ExchangeFailure> result) =>
    switch (result) {
      Ok(:final value) => WriteDone(value),
      Err(:final failure) => switch (failure) {
        ExchangeNotAuthenticatedFailure() ||
        RecipientsNotAuthenticatedFailure() => const WriteNotSent(
          ExchangeNotSentReason.signedOut,
        ),
        ExchangeCredentialReadFailure() => const WriteNotSent(
          ExchangeNotSentReason.credentialUnavailable,
        ),
        ExchangeOperationStaleFailure() => const WriteNotSent(
          ExchangeNotSentReason.sessionChanged,
        ),
        ExchangeSessionRejectedFailure() => const WriteSessionRejected(),
        ExchangeOrderRejectedFailure(:final apiCode, :final rpcCode) =>
          WriteRefused(ExchangeRefusal(apiCode: apiCode, rpcCode: rpcCode)),
        ExchangeVirtualIbanNotAvailableFailure() ||
        ExchangeEuResidencyRequiredFailure() ||
        RecipientsVirtualIbanNotAvailableFailure() ||
        RecipientsEuResidencyRequiredFailure() => const WriteRefused(
          ExchangeRefusal(),
        ),
        _ => WriteOutcomeUnknown(failure.runtimeType.toString()),
      },
    };
