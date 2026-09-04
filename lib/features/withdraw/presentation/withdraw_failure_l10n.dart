import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/withdraw/domain/withdraw_failure.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

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
    WithdrawUnexpectedFailure() => context.loc.withdrawUnexpectedError,
  };
}

/// Formats a bound without a unit, because the surrounding sentence already
/// carries the currency in its own `{currency}` placeholder.
String _formatBound(double amount) =>
    NumberFormat('#,##0.########').format(amount);
