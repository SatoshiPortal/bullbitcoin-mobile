import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/transaction_review_failure.dart';
import 'package:flutter/widgets.dart';

/// User-facing, localized message for each [TransactionReviewFailure]. The
/// `sealed` switch makes a missing message a compile error. Never returns the
/// raw `logMessage`.
extension TransactionReviewFailureL10n on TransactionReviewFailure {
  String toTranslated(BuildContext context) => switch (this) {
        TransactionReviewFetchFailure(:final txid) =>
          context.loc.coreScreensFetchFailed(txid),
        TransactionReviewNoServersFailure() =>
          context.loc.coreScreensNoServersAvailable,
        TransactionReviewInputResolutionFailure(:final parentTxId, :final vout) =>
          context.loc.coreScreensInputResolutionFailed(vout, parentTxId),
        TransactionReviewUnexpectedFailure() =>
          context.loc.oopsSomethingWentWrong,
      };
}
