import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/fiat_settlement_failure.dart';

/// Stable Bullnym application error codes for fiat settlement. These wire
/// strings match the Bullnym server contract (PRs #197/#198) exactly: the
/// credential codes are the `BULL_BITCOIN_*` names the server emits; KYC is
/// `FIAT_CONVERSION_KYC_REQUIRED`.
const String fiatSettlementKycRequiredCode = 'FIAT_CONVERSION_KYC_REQUIRED';
const String fiatSettlementCredentialRequiredCode = 'BULL_BITCOIN_CREDENTIAL_REQUIRED';
const String fiatSettlementCredentialInvalidCode = 'BULL_BITCOIN_CREDENTIAL_INVALID';

/// Maps a transport-level [BullnymFailure] to the closed feature failure set,
/// preserving exactly the distinctions the validated error outcomes require:
/// KYC vs credential vs dependency-unavailable (503) vs Bullnym-unreachable.
FiatSettlementFailure mapBullnymToFiatSettlementFailure(
  BullnymFailure failure,
) {
  switch (failure.kind) {
    case BullnymFailureKind.invalidInput:
      return const FiatSettlementFailure.invalidInput();
    case BullnymFailureKind.network:
    case BullnymFailureKind.timeout:
      return const FiatSettlementFailure.bullnymUnreachable();
    case BullnymFailureKind.serverRejectedRequest:
      switch (failure.code) {
        case fiatSettlementKycRequiredCode:
          return const FiatSettlementFailure.kycRequired();
        case fiatSettlementCredentialRequiredCode:
        case fiatSettlementCredentialInvalidCode:
          return const FiatSettlementFailure.credentialProblem();
        default:
          if (failure.statusCode == 503) {
            return const FiatSettlementFailure.dependencyUnavailable();
          }
          return const FiatSettlementFailure.unexpected();
      }
    case BullnymFailureKind.unexpectedHttpStatus:
      if (failure.statusCode == 503) {
        return const FiatSettlementFailure.dependencyUnavailable();
      }
      return const FiatSettlementFailure.unexpected();
    case BullnymFailureKind.emptyResponse:
    case BullnymFailureKind.invalidServerResponse:
    case BullnymFailureKind.signingFailed:
    case BullnymFailureKind.unexpected:
      return const FiatSettlementFailure.unexpected();
  }
}
