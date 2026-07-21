import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/fiat_settlement_failure.dart';

/// Stable Bullnym application error codes for fiat settlement.
//
// PENDING DECISION (credential error codes): these two credential codes are
// currently pinned to FIAT_CREDENTIAL_REQUIRED / FIAT_CREDENTIAL_INVALID, but
// the server (Bullnym PR #198) presently emits
// BULL_BITCOIN_CREDENTIAL_REQUIRED / BULL_BITCOIN_CREDENTIAL_INVALID. The owner
// has NOT yet decided which side renames, so these strings are intentionally
// left unchanged. Do not "fix" them until that decision lands; whichever side
// renames, both must agree before this mapping can classify a credential
// problem in production.
const String fiatSettlementKycRequiredCode = 'FIAT_CONVERSION_KYC_REQUIRED';
const String fiatSettlementCredentialRequiredCode = 'FIAT_CREDENTIAL_REQUIRED';
const String fiatSettlementCredentialInvalidCode = 'FIAT_CREDENTIAL_INVALID';

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
