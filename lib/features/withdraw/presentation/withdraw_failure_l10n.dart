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
        _formatBound(context, minAmount),
        currency,
      ),
    WithdrawAboveMaxAmountFailure(:final maxAmount, :final currency) =>
      context.loc.withdrawAboveMaxAmountError(
        _formatBound(context, maxAmount),
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
///
/// The locale is explicit: the app never sets `Intl.defaultLocale`, so a
/// bare `NumberFormat` would format as `en_US` and drop "5,000" into an
/// otherwise French sentence, where it reads as five. `localeName` is what
/// `AppLocalizations` already canonicalized for intl, so `pt_BR` and
/// `hi_Latn` resolve the same way the strings around them do.
String _formatBound(BuildContext context, double amount) =>
    NumberFormat('#,##0.########', context.loc.localeName).format(amount);
