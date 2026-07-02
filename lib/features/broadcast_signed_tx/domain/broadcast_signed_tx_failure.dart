import 'package:bb_mobile/core/failures/failure.dart';

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
  const InvalidTransactionFailure();
}

final class InvalidPushTxFailure extends BroadcastSignedTxFailure {
  const InvalidPushTxFailure();
}

final class BroadcastFailedFailure extends BroadcastSignedTxFailure {
  const BroadcastFailedFailure();
}

/// Catch-all. [logMessage] is for logs ONLY and MUST never reach the UI —
/// the presentation extension returns the shared generic string.
final class BroadcastUnexpectedFailure extends BroadcastSignedTxFailure {
  const BroadcastUnexpectedFailure([super.logMessage]);
}
