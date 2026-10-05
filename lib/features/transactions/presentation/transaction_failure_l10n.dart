import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:flutter/widgets.dart';

extension TransactionFailureL10n on TransactionFailure {
  String toTranslated(BuildContext context) => switch (this) {
    TransactionAggregationFailure() => context.loc.transactionListLoadingFailed,
    TransactionNotFoundFailure() => context.loc.transactionDetailLoadError,
    TransactionSwapUnavailableFailure() =>
      context.loc.transactionDetailLoadError,
    TransactionExportEmptyFailure() => context.loc.exportTransactionsEmpty,
    TransactionExportInvalidRangeFailure() =>
      context.loc.exportTransactionsInvalidDateRange,
    TransactionExportFailure() => context.loc.exportTransactionsError,
    TransactionPayjoinFallbackUnavailableFailure() =>
      context.loc.transactionPayjoinOriginalUnavailable,
    TransactionPayjoinBroadcastFailure() =>
      context.loc.transactionPayjoinBroadcastFailed,
    TransactionLabelLimitFailure() => context.loc.transactionLabelLimitReached,
    // Never `logMessage`.
    TransactionUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
