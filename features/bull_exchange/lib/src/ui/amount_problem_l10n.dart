import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:exchange/steps.dart';
import 'package:flutter/widgets.dart';

/// The text of an amount the amount step refused.
extension AmountProblemL10n on AmountProblem {
  String toTranslated(BuildContext context, String currency) => switch (this) {
    AmountNoRate() => context.loc.exchangeAmountNoRate,
    AmountInvalid() => context.loc.exchangeAmountInputValidationInvalid,
    AmountBelowMinimum(:final minFiat) => context.loc.exchangeOrderBelowMinimum(
      minFiat.toString(),
      currency,
    ),
    AmountAboveMaximum(:final maxFiat) => context.loc.exchangeOrderAboveMaximum(
      maxFiat.toString(),
      currency,
    ),
    AmountOverBalance() =>
      context.loc.exchangeAmountInputValidationInsufficient,
    AmountKycNeeded() => context.loc.exchangeAmountKycNeeded,
  };
}
