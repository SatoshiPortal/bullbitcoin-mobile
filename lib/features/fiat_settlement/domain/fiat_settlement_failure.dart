import 'package:bb_mobile/core/failures/failure.dart';

/// Closed set of fiat-settlement failures, mapped from the Bullnym transport
/// boundary and rendered by the presentation layer into the exact validated
/// action sets. No raw server or credential detail is carried here.
enum FiatSettlementFailureKind {
  /// Account lacks the KYC permissions to activate fiat conversion.
  /// Server code `FIAT_CONVERSION_KYC_REQUIRED`.
  kycRequired,

  /// The scoped credential is missing (none supplied and none stored) or the
  /// server rejected it as invalid/revoked/wrong-scope. Server codes
  /// `BULL_BITCOIN_CREDENTIAL_REQUIRED` / `BULL_BITCOIN_CREDENTIAL_INVALID`, and the local
  /// "no scoped key available to submit" case. UI offers Reconnect.
  credentialProblem,

  /// Bullnym reached its Bull Bitcoin dependency but that dependency was
  /// unavailable (HTTP 503). UI offers Retry.
  dependencyUnavailable,

  /// Bullnym itself could not be reached (network/timeout). Activation cannot
  /// proceed; UI offers Retry only (no Bitcoin-only continuation).
  bullnymUnreachable,

  /// Local validation / preparation problem before any submission.
  invalidInput,

  /// Anything else (malformed response, signing failure, unexpected).
  unexpected,
}

sealed class FiatSettlementFailure extends Failure {
  final FiatSettlementFailureKind kind;

  const FiatSettlementFailure._(this.kind) : super(null);

  const factory FiatSettlementFailure.kycRequired() =
      FiatSettlementKycRequiredFailure;
  const factory FiatSettlementFailure.credentialProblem() =
      FiatSettlementCredentialProblemFailure;
  const factory FiatSettlementFailure.dependencyUnavailable() =
      FiatSettlementDependencyUnavailableFailure;
  const factory FiatSettlementFailure.bullnymUnreachable() =
      FiatSettlementBullnymUnreachableFailure;
  const factory FiatSettlementFailure.invalidInput() =
      FiatSettlementInvalidInputFailure;
  const factory FiatSettlementFailure.unexpected() =
      FiatSettlementUnexpectedFailure;

  @override
  String toString() => 'FiatSettlementFailure($kind)';
}

final class FiatSettlementKycRequiredFailure extends FiatSettlementFailure {
  const FiatSettlementKycRequiredFailure()
    : super._(FiatSettlementFailureKind.kycRequired);
}

final class FiatSettlementCredentialProblemFailure
    extends FiatSettlementFailure {
  const FiatSettlementCredentialProblemFailure()
    : super._(FiatSettlementFailureKind.credentialProblem);
}

final class FiatSettlementDependencyUnavailableFailure
    extends FiatSettlementFailure {
  const FiatSettlementDependencyUnavailableFailure()
    : super._(FiatSettlementFailureKind.dependencyUnavailable);
}

final class FiatSettlementBullnymUnreachableFailure
    extends FiatSettlementFailure {
  const FiatSettlementBullnymUnreachableFailure()
    : super._(FiatSettlementFailureKind.bullnymUnreachable);
}

final class FiatSettlementInvalidInputFailure extends FiatSettlementFailure {
  const FiatSettlementInvalidInputFailure()
    : super._(FiatSettlementFailureKind.invalidInput);
}

final class FiatSettlementUnexpectedFailure extends FiatSettlementFailure {
  const FiatSettlementUnexpectedFailure()
    : super._(FiatSettlementFailureKind.unexpected);
}
