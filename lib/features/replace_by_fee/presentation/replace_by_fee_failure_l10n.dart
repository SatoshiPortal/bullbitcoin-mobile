import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/replace_by_fee/domain/replace_by_fee_failure.dart';
import 'package:flutter/widgets.dart';

extension ReplaceByFeeFailureL10n on ReplaceByFeeFailure {
  String toTranslated(BuildContext context) => switch (this) {
    ReplaceByFeeNoFeeRateSelectedFailure() =>
      context.loc.replaceByFeeErrorNoFeeRateSelected,
    ReplaceByFeeFeeRateTooLowFailure() =>
      context.loc.replaceByFeeErrorFeeRateTooLow,
    ReplaceByFeeNetworkFeesFailure() => context.loc.oopsSomethingWentWrong,
    ReplaceByFeeUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
