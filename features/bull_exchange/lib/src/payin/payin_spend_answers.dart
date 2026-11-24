import 'package:bull_payjoin/bull_payjoin.dart'
    show PayjoinSenderSession, PayjoinSession, PayjoinStatus;
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';

/// The wallet's answer to a payin broadcast of [txid] as the closed payin
/// set. Only a node refusal and the spend's own pre-send checks say nothing
/// went out; every other failure, including one this mapping can't classify,
/// may have put the payin on the network and is an unknown outcome (looked
/// up, never sent as a new payin).
PayinBroadcastOutcome payinBroadcastOf(
  Result<SpendBroadcastReceipt, SpendFailure> result, {
  required String txid,
}) => switch (result) {
  Ok(:final value) => PayinBroadcastAccepted(value.txid),
  Err(:final failure) => switch (failure) {
    SpendBroadcastRejectedFailure() => const PayinBroadcastRefused(
      PayinRefusal.nodeRejected,
    ),
    SpendBroadcastConnectionFailure() => const PayinBroadcastNotSent(
      PayinNotSentReason.noConnection,
    ),
    SpendUnavailableFailure() => const PayinBroadcastNotSent(
      PayinNotSentReason.walletBusy,
    ),
    SpendDeveloperAuthorizationFailure() => const PayinBroadcastNotSent(
      PayinNotSentReason.notAuthorized,
    ),
    // Already in a block is this payin on the network: look it up.
    SpendAlreadyInChainFailure() ||
    SpendBroadcastOutcomeUnknownFailure() ||
    SpendInsufficientFundsFailure() ||
    SpendInsufficientFundsForFeesFailure() ||
    SpendFeeRateTooLowFailure() ||
    SpendOriginalSignaturesFailure() ||
    SpendNoSpendableInputsFailure() ||
    SpendSelectedInputsUnavailableFailure() ||
    SpendNetworkMismatchFailure() ||
    SpendSignedTransactionMismatchFailure() ||
    SpendInvalidRequestFailure() ||
    SpendInvalidTransactionFailure() ||
    SpendSigningRefusedFailure() ||
    SpendBuildRefusedFailure() ||
    SpendConsolidationRequiredFailure() ||
    SpendConsolidationInterruptedFailure() ||
    SpendPayjoinUnavailableFailure() ||
    SpendUnexpectedFailure() => PayinBroadcastOutcomeUnknown(txid),
  },
};

/// Why preparing or signing a payin failed. Neither sends anything.
PayinBuildProblem payinBuildProblemOf(SpendFailure failure) =>
    switch (failure) {
      SpendInsufficientFundsFailure() ||
      SpendInsufficientFundsForFeesFailure() ||
      SpendNoSpendableInputsFailure() ||
      SpendSelectedInputsUnavailableFailure() =>
        PayinBuildProblem.insufficientFunds,
      SpendFeeRateTooLowFailure() => PayinBuildProblem.feeTooLow,
      SpendUnavailableFailure() => PayinBuildProblem.walletBusy,
      SpendConsolidationRequiredFailure() =>
        PayinBuildProblem.consolidationRequired,
      SpendSigningRefusedFailure() ||
      SpendOriginalSignaturesFailure() ||
      SpendSignedTransactionMismatchFailure() =>
        PayinBuildProblem.signingRefused,
      SpendDeveloperAuthorizationFailure() => PayinBuildProblem.notAuthorized,
      SpendNetworkMismatchFailure() ||
      SpendInvalidRequestFailure() ||
      SpendInvalidTransactionFailure() ||
      SpendBuildRefusedFailure() => PayinBuildProblem.invalid,
      SpendBroadcastRejectedFailure() ||
      SpendBroadcastConnectionFailure() ||
      SpendAlreadyInChainFailure() ||
      SpendBroadcastOutcomeUnknownFailure() ||
      SpendConsolidationInterruptedFailure() ||
      SpendPayjoinUnavailableFailure() ||
      SpendUnexpectedFailure() => PayinBuildProblem.unexpected,
    };

/// A payjoin session's state as the payin machine reads it. A session that
/// ended with a broadcast but no txid recorded is read as expired: the payin
/// then looks the original up instead of being offered again.
PayjoinProgress payjoinProgressFrom({
  required PayjoinStatus status,
  required bool spendBlocked,
  required String? txid,
  required String? originalTxid,
}) => switch (status) {
  PayjoinStatus.started || PayjoinStatus.requested || PayjoinStatus.proposed =>
    spendBlocked ? const PayjoinPaused() : const PayjoinNegotiating(),
  PayjoinStatus.completed => switch (txid ?? originalTxid) {
    final sent? => PayjoinSent(sent),
    null => const PayjoinExpired(),
  },
  PayjoinStatus.aborted => switch (originalTxid) {
    final sent? => PayjoinSent(sent),
    null => const PayjoinExpired(),
  },
  PayjoinStatus.expired => const PayjoinExpired(),
};

PayjoinProgress payjoinProgressOf(PayjoinSession session) =>
    payjoinProgressFrom(
      status: session.status,
      spendBlocked:
          session is PayjoinSenderSession && session.spendFailure != null,
      txid: session.txId,
      originalTxid: session.originalTxId,
    );
