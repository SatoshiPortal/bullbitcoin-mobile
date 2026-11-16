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
  outcomeUnknown,
  native,
  budgetExhausted,
  closed,
}

sealed class ArkWalletFailure extends Failure {
  final ArkFailureReason reason;
  const ArkWalletFailure(this.reason) : super();
}

final class ArkUnavailableFailure extends ArkWalletFailure {
  const ArkUnavailableFailure([super.reason = ArkFailureReason.unavailable]);
}

final class ArkWriterBusyFailure extends ArkWalletFailure {
  const ArkWriterBusyFailure() : super(ArkFailureReason.writerBusy);
}

final class ArkStorageFailure extends ArkWalletFailure {
  const ArkStorageFailure([super.reason = ArkFailureReason.storage]);
}

final class ArkValidationFailure extends ArkWalletFailure {
  const ArkValidationFailure([super.reason = ArkFailureReason.validation]);
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

final class ArkOutcomeUnknownFailure extends ArkWalletFailure {
  final String operationId;
  const ArkOutcomeUnknownFailure(this.operationId)
    : super(ArkFailureReason.outcomeUnknown);
}

final class ArkNativeFailure extends ArkWalletFailure {
  const ArkNativeFailure([super.reason = ArkFailureReason.native]);
}
