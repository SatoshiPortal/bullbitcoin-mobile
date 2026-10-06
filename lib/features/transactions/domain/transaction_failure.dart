import 'package:bb_mobile/core/failures/failure.dart';

sealed class TransactionFailure extends Failure {
  const TransactionFailure([super.logMessage]);
}

/// The transaction list could not be assembled from wallets, swaps and orders.
final class TransactionAggregationFailure extends TransactionFailure {
  const TransactionAggregationFailure([super.logMessage]);
}

/// The requested transaction is not in the local store.
final class TransactionNotFoundFailure extends TransactionFailure {
  const TransactionNotFoundFailure([super.logMessage]);
}

/// The swap behind an exchange order could not be read or watched.
final class TransactionSwapUnavailableFailure extends TransactionFailure {
  const TransactionSwapUnavailableFailure([super.logMessage]);
}

/// There is nothing in the selected range to export.
final class TransactionExportEmptyFailure extends TransactionFailure {
  const TransactionExportEmptyFailure([super.logMessage]);
}

/// The selected export range starts after it ends.
final class TransactionExportInvalidRangeFailure extends TransactionFailure {
  const TransactionExportInvalidRangeFailure([super.logMessage]);
}

/// The CSV could not be built or written.
final class TransactionExportFailure extends TransactionFailure {
  const TransactionExportFailure([super.logMessage]);
}

/// The payjoin original transaction is no longer available to broadcast —
/// distinct from a failed attempt, and the UI offers different wording.
final class TransactionPayjoinFallbackUnavailableFailure
    extends TransactionFailure {
  const TransactionPayjoinFallbackUnavailableFailure([super.logMessage]);
}

/// Re-broadcasting the payjoin original transaction failed.
final class TransactionPayjoinBroadcastFailure extends TransactionFailure {
  const TransactionPayjoinBroadcastFailure([super.logMessage]);
}

/// More labels than the exchange accepts on one transaction.
final class TransactionLabelLimitFailure extends TransactionFailure {
  const TransactionLabelLimitFailure([super.logMessage]);
}

/// Catch-all. [logMessage] is for logs ONLY and MUST never reach the UI.
final class TransactionUnexpectedFailure extends TransactionFailure {
  const TransactionUnexpectedFailure([super.logMessage]);
}
