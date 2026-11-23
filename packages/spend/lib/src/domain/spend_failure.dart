import 'package:primitives/primitives.dart' show Failure;

sealed class SpendFailure extends Failure {
  const SpendFailure();
}

final class SpendInsufficientFundsFailure extends SpendFailure {
  const SpendInsufficientFundsFailure();
}

final class SpendInsufficientFundsForFeesFailure extends SpendFailure {
  const SpendInsufficientFundsForFeesFailure();
}

final class SpendFeeRateTooLowFailure extends SpendFailure {
  const SpendFeeRateTooLowFailure();
}

final class SpendOriginalSignaturesFailure extends SpendFailure {
  final bool unverifiable;
  const SpendOriginalSignaturesFailure({required this.unverifiable});
}

final class SpendNoSpendableInputsFailure extends SpendFailure {
  const SpendNoSpendableInputsFailure();
}

final class SpendSelectedInputsUnavailableFailure extends SpendFailure {
  const SpendSelectedInputsUnavailableFailure();
}

final class SpendNetworkMismatchFailure extends SpendFailure {
  const SpendNetworkMismatchFailure();
}

final class SpendDeveloperAuthorizationFailure extends SpendFailure {
  const SpendDeveloperAuthorizationFailure();
}

final class SpendSignedTransactionMismatchFailure extends SpendFailure {
  const SpendSignedTransactionMismatchFailure();
}

final class SpendInvalidRequestFailure extends SpendFailure {
  const SpendInvalidRequestFailure();
}

final class SpendInvalidTransactionFailure extends SpendFailure {
  const SpendInvalidTransactionFailure();
}

final class SpendSigningRefusedFailure extends SpendFailure {
  const SpendSigningRefusedFailure();
}

final class SpendUnavailableFailure extends SpendFailure {
  final bool busy;
  final bool replacementPending;
  const SpendUnavailableFailure({
    this.busy = false,
    this.replacementPending = false,
  });
}

final class SpendBuildRefusedFailure extends SpendFailure {
  const SpendBuildRefusedFailure();
}

final class SpendConsolidationRequiredFailure extends SpendFailure {
  const SpendConsolidationRequiredFailure();
}

enum SpendBroadcastRejection { nodeRejected }

final class SpendBroadcastRejectedFailure extends SpendFailure {
  final SpendBroadcastRejection category;
  const SpendBroadcastRejectedFailure(this.category);
}

final class SpendAlreadyInChainFailure extends SpendFailure {
  const SpendAlreadyInChainFailure();
}

/// A relay may already have seen this transaction. Do not retry or pay again.
final class SpendBroadcastOutcomeUnknownFailure extends SpendFailure {
  const SpendBroadcastOutcomeUnknownFailure();
}

final class SpendConsolidationInterruptedFailure extends SpendFailure {
  final List<String> acceptedTxids;
  final SpendFailure cause;

  SpendConsolidationInterruptedFailure(List<String> acceptedTxids, this.cause)
    : acceptedTxids = List.unmodifiable(acceptedTxids);
}

final class SpendPayjoinUnavailableFailure extends SpendFailure {
  const SpendPayjoinUnavailableFailure();
}

final class SpendUnexpectedFailure extends SpendFailure {
  const SpendUnexpectedFailure();
}
