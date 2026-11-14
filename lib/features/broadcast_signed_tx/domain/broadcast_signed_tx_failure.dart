import 'package:primitives/primitives.dart' show Failure;

/// Closed set of every failure the broadcast flow surfaces to the user.
///
/// Foreign errors (BDK, Electrum, NFC parsing) are caught at the boundary that
/// owns the call (the cubit for scan/parse, the broadcast use-case) and mapped
/// into one of these variants; the raw reason stays in the logs. `sealed` keeps
/// it closed (exhaustive switches; no foreign variants). Pure Dart — the
/// user-facing message lives in `broadcast_signed_tx_failure_l10n.dart`.
sealed class BroadcastSignedTxFailure extends Failure {
  const BroadcastSignedTxFailure([super.logMessage]);
}

final class InvalidTransactionFailure extends BroadcastSignedTxFailure {
  const InvalidTransactionFailure([super.logMessage]);
}

final class InvalidPushTxFailure extends BroadcastSignedTxFailure {
  const InvalidPushTxFailure();
}

final class BroadcastFailedFailure extends BroadcastSignedTxFailure {
  const BroadcastFailedFailure();
}

/// The node already has this transaction in a block: there is nothing left to
/// broadcast.
final class TransactionAlreadyInChainFailure extends BroadcastSignedTxFailure {
  const TransactionAlreadyInChainFailure();
}

/// The node refused the transaction (bitcoind -26): it may be incompletely
/// signed, invalid, or in conflict with another payment.
final class TransactionRejectedFailure extends BroadcastSignedTxFailure {
  const TransactionRejectedFailure();
}

/// The broadcast failed for a reason that does not show whether the
/// transaction reached the network.
final class BroadcastOutcomeUnknownFailure extends BroadcastSignedTxFailure {
  const BroadcastOutcomeUnknownFailure();
}

/// The app refused, before any network call, to broadcast on a network the
/// current settings do not enable.
final class BroadcastNetworkNotEnabledFailure extends BroadcastSignedTxFailure {
  const BroadcastNetworkNotEnabledFailure();
}

final class PsbtFinalizationFailure extends BroadcastSignedTxFailure {
  const PsbtFinalizationFailure();
}

/// Catch-all. [logMessage] is for logs ONLY and MUST never reach the UI —
/// the presentation extension returns the shared generic string.
final class BroadcastUnexpectedFailure extends BroadcastSignedTxFailure {
  const BroadcastUnexpectedFailure([super.logMessage]);
}
