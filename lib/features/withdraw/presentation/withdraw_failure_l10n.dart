import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/withdraw/domain/withdraw_failure.dart';
import 'package:flutter/widgets.dart';
import 'package:bull_ui/bull_ui.dart' show BullNumberFormat;

extension WithdrawFailureL10n on WithdrawFailure {
  String toTranslated(BuildContext context) => switch (this) {
    WithdrawUnauthenticatedFailure() =>
      context.loc.withdrawUnauthenticatedError,

    // Name the bound. A limit error the user cannot act on is barely better
    // than no message: they need the number to fix the amount.
    WithdrawBelowMinAmountFailure(:final minAmount, :final currency) =>
      context.loc.withdrawBelowMinAmountError(
        _formatBound(minAmount),
        currency,
      ),
    WithdrawAboveMaxAmountFailure(:final maxAmount, :final currency) =>
      context.loc.withdrawAboveMaxAmountError(
        _formatBound(maxAmount),
        currency,
      ),

    // Never `logMessage`: the raw reason is logged at the boundary and is
    // never fit to show a user. The copy stays actionable — "try again or
    // contact support" — rather than a bare "something went wrong", matching
    // `buyUnexpectedError` and `sellUnexpectedError`.
    WithdrawConfidentialSepaNotActivatedFailure() =>
      context.loc.withdrawConfidentialSepaNotActivatedError,
    WithdrawUnexpectedFailure() => context.loc.withdrawUnexpectedError,
  };
}

/// Formats a bound without a unit, because the surrounding sentence already
/// carries the currency in its own `{currency}` placeholder.
///
/// Written with the app's separators, like every other amount: "5 000" in a
/// French sentence, where "5,000" would read as five.
String _formatBound(double amount) =>
    BullNumberFormat.decimal(amount, maxDecimals: 8);
