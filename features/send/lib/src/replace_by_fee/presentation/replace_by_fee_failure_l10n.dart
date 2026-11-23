import 'package:send/src/send_localizations.dart';
import 'package:send/src/replace_by_fee/domain/replace_by_fee_failure.dart';
import 'package:flutter/widgets.dart';

extension ReplaceByFeeFailureL10n on ReplaceByFeeFailure {
  String toTranslated(BuildContext context) => switch (this) {
    ReplaceByFeeSpendBlockedFailure(:final replacementPending, :final busy) =>
      busy
          ? context.loc.walletSpendBusy
          : replacementPending
          ? context.loc.walletSpendReplacementUnavailable
          : context.loc.walletSpendAwaitingObservation,
    ReplaceByFeeNoFeeRateSelectedFailure() =>
      context.loc.replaceByFeeErrorNoFeeRateSelected,
    ReplaceByFeeFeeRateTooLowFailure() =>
      context.loc.replaceByFeeErrorFeeRateTooLow,
    ReplaceByFeeNetworkFeesFailure() => context.loc.oopsSomethingWentWrong,
    ReplaceByFeeManipulatedTransactionFailure() =>
      context.loc.replaceByFeeManipulatedTransaction,
    ReplaceByFeeUnverifiableTransactionFailure() =>
      context.loc.replaceByFeeUnverifiableTransaction,
    ReplaceByFeeUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
