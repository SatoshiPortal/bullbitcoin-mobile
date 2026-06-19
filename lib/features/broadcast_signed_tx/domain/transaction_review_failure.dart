import 'package:bb_mobile/core/failures/failure.dart';

/// Closed set of failures raised while building a `ReviewableTransaction` for
/// the broadcast review screen.
///
/// Port-layer errors are mapped into these variants by the use-case at the
/// boundary — the presentation layer never sees a foreign error type. `sealed`
/// keeps it closed. Pure Dart — the user-facing message lives in
/// `transaction_review_failure_l10n.dart`.
sealed class TransactionReviewFailure extends Failure {
  const TransactionReviewFailure([super.logMessage]);
}

/// Failed to fetch a parent transaction needed to resolve an input value.
final class TransactionReviewFetchFailure extends TransactionReviewFailure {
  final String txid;

  const TransactionReviewFetchFailure({required this.txid, String? logMessage})
    : super(logMessage);
}

/// No Electrum servers configured / reachable for the active network.
final class TransactionReviewNoServersFailure extends TransactionReviewFailure {
  final String? network;

  const TransactionReviewNoServersFailure({this.network});
}

/// An input's parent transaction was found but the referenced output index
/// does not exist.
final class TransactionReviewInputResolutionFailure
    extends TransactionReviewFailure {
  final String parentTxId;
  final int vout;

  const TransactionReviewInputResolutionFailure({
    required this.parentTxId,
    required this.vout,
  });
}

/// Catch-all. [logMessage] is for logs ONLY and MUST never reach the UI —
/// the presentation extension returns the shared generic string.
final class TransactionReviewUnexpectedFailure
    extends TransactionReviewFailure {
  const TransactionReviewUnexpectedFailure([super.logMessage]);
}
