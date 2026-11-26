import 'package:primitives/primitives.dart';

enum ArkFailureReason {
  unavailable,
  accountMissing,
  serverUnreachable,
  chainUnreachable,
  storeIncompatible,
  storage,
  validation,
  belowMinimum,
  dust,
  unsupportedMethod,
  identityMismatch,
  invalidSelection,
  staleQuote,
  recoveryRequired,
  writerBusy,
  insufficientFunds,
  exitFeesShort,
  outcomeUnknown,
  native,
  budgetExhausted,
  closed,

  /// The headless renewal policy refused to read the seed (D92). Not a
  /// recovery: nothing is wrong with the wallet, the view is protected.
  renewalNotPermitted,
}

sealed class ArkWalletFailure extends Failure {
  final ArkFailureReason reason;
  const ArkWalletFailure(this.reason) : super();
}

final class ArkUnavailableFailure extends ArkWalletFailure {
  const ArkUnavailableFailure([super.reason = ArkFailureReason.unavailable]);
}

/// Renewal does not run headless: it would hand the Ark child's words to the
/// native opener from a process that has no session (D92). Nothing is wrong
/// with the wallet; the foreground renews.
final class ArkRenewalDisabledFailure extends ArkWalletFailure {
  const ArkRenewalDisabledFailure()
    : super(ArkFailureReason.renewalNotPermitted);
}

final class ArkWriterBusyFailure extends ArkWalletFailure {
  const ArkWriterBusyFailure() : super(ArkFailureReason.writerBusy);
}

final class ArkStorageFailure extends ArkWalletFailure {
  const ArkStorageFailure([super.reason = ArkFailureReason.storage]);
}

final class ArkValidationFailure extends ArkWalletFailure {
  final Sats? minimum;
  const ArkValidationFailure([super.reason = ArkFailureReason.validation])
    : minimum = null;
  const ArkValidationFailure.belowMinimum(Sats this.minimum)
    : super(ArkFailureReason.belowMinimum);
}

final class ArkStaleQuoteFailure extends ArkWalletFailure {
  const ArkStaleQuoteFailure() : super(ArkFailureReason.staleQuote);
}

final class ArkRecoveryRequiredFailure extends ArkWalletFailure {
  const ArkRecoveryRequiredFailure() : super(ArkFailureReason.recoveryRequired);
}

final class ArkInsufficientFundsFailure extends ArkWalletFailure {
  const ArkInsufficientFundsFailure()
    : super(ArkFailureReason.insufficientFunds);
}

/// An emergency exit has a transaction to broadcast but the on-chain reserve
/// cannot pay its fee yet. Nothing was broadcast; the exit waits.
final class ArkExitFeesShortFailure extends ArkWalletFailure {
  /// What the confirmed reserve lacks to pay the fee now.
  final Sats missing;

  /// Already received by the reserve but not yet confirmed.
  final Sats incoming;

  const ArkExitFeesShortFailure({required this.missing, required this.incoming})
    : super(ArkFailureReason.exitFeesShort);
}

final class ArkOutcomeUnknownFailure extends ArkWalletFailure {
  final String operationId;
  const ArkOutcomeUnknownFailure(this.operationId)
    : super(ArkFailureReason.outcomeUnknown);
}

final class ArkNativeFailure extends ArkWalletFailure {
  const ArkNativeFailure([super.reason = ArkFailureReason.native]);
}
