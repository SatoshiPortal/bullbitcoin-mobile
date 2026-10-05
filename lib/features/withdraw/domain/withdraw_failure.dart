import 'package:bb_mobile/core/failures/failure.dart';

sealed class WithdrawFailure extends Failure {
  const WithdrawFailure([super.logMessage]);
}

/// The API rejected the request because the session is not (or no longer)
/// authenticated.
final class WithdrawUnauthenticatedFailure extends WithdrawFailure {
  const WithdrawUnauthenticatedFailure([super.logMessage]);
}

/// The amount is under the minimum this account can withdraw.
///
/// [minAmount] is denominated in [currency], which the API picks and can be
/// either a fiat currency or BTC/LBTC. Both travel with the failure so a screen
/// can name the bound rather than receive it pre-formatted.
final class WithdrawBelowMinAmountFailure extends WithdrawFailure {
  final double minAmount;
  final String currency;

  const WithdrawBelowMinAmountFailure({
    required this.minAmount,
    required this.currency,
    String? logMessage,
  }) : super(logMessage);
}

/// The amount is over the maximum this account can withdraw. See
/// [WithdrawBelowMinAmountFailure] for how [currency] is chosen.
final class WithdrawAboveMaxAmountFailure extends WithdrawFailure {
  final double maxAmount;
  final String currency;

  const WithdrawAboveMaxAmountFailure({
    required this.maxAmount,
    required this.currency,
    String? logMessage,
  }) : super(logMessage);
}

/// The catch-all.
///
/// Carries the raw reason in `logMessage` for diagnosis only — the translation
/// deliberately ignores it and returns a generic message.
final class WithdrawUnexpectedFailure extends WithdrawFailure {
  const WithdrawUnexpectedFailure([super.logMessage]);
}
