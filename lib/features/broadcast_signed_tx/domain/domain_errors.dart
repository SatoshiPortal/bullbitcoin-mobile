import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/widgets.dart';

/// Errors raised while building a [ReviewableTransaction].
///
/// Closed set of failures the transaction-review screen surfaces to the user.
/// Port-layer errors are mapped into these variants by the usecase at the
/// boundary — the presentation layer never sees a foreign error type. `sealed`
/// keeps it closed; the abstract `toTranslated` keeps each user-facing message
/// next to its variant.
sealed class TransactionReviewError {
  const TransactionReviewError();

  /// Localized, user-safe message. Never returns raw/technical detail.
  String toTranslated(BuildContext context);
}

/// Failed to fetch a parent transaction needed to resolve an input value.
final class TransactionReviewFetchFailed extends TransactionReviewError {
  const TransactionReviewFetchFailed({required this.txid, this.message});

  final String txid;
  final String? message; // logged-only context, never shown

  @override
  String toTranslated(BuildContext context) =>
      context.loc.coreScreensFetchFailed(txid);
}

/// No Electrum servers configured / reachable for the active network.
final class TransactionReviewNoServersAvailable extends TransactionReviewError {
  final String? network;

  const TransactionReviewNoServersAvailable({this.network});

  @override
  String toTranslated(BuildContext context) =>
      context.loc.coreScreensNoServersAvailable;
}

/// An input's parent transaction was found but the referenced output index
/// does not exist.
final class TransactionReviewInputResolutionFailed
    extends TransactionReviewError {
  final String parentTxId;
  final int vout;

  const TransactionReviewInputResolutionFailed({
    required this.parentTxId,
    required this.vout,
  });

  @override
  String toTranslated(BuildContext context) =>
      context.loc.coreScreensInputResolutionFailed(vout, parentTxId);
}

/// Catch-all. [message] is for logs only and MUST never reach the UI —
/// `toTranslated` returns the shared generic string, not [message].
final class UnexpectedTransactionReviewError extends TransactionReviewError {
  final String? message;

  const UnexpectedTransactionReviewError(this.message);

  @override
  String toTranslated(BuildContext context) =>
      context.loc.oopsSomethingWentWrong;
}
