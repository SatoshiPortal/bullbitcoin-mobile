import 'package:bb_mobile/core/failures/failure.dart';

sealed class BuyFailure extends Failure {
  const BuyFailure([super.logMessage]);
}

/// The API rejected the request because the session is not (or no longer)
/// authenticated.
final class BuyUnauthenticatedFailure extends BuyFailure {
  const BuyUnauthenticatedFailure([super.logMessage]);
}

/// The amount is under the minimum this account can buy.
///
/// [minAmount] is denominated in [currency], which the API picks and can be
/// either a fiat currency or BTC/LBTC. The amount input screen reads both to
/// name the bound, so they are carried rather than pre-formatted.
final class BuyBelowMinAmountFailure extends BuyFailure {
  final double minAmount;
  final String currency;

  const BuyBelowMinAmountFailure({
    required this.minAmount,
    required this.currency,
    String? logMessage,
  }) : super(logMessage);
}

/// The amount is over the maximum this account can buy. See
/// [BuyBelowMinAmountFailure] for how [currency] is chosen.
final class BuyAboveMaxAmountFailure extends BuyFailure {
  final double maxAmount;
  final String currency;

  const BuyAboveMaxAmountFailure({
    required this.maxAmount,
    required this.currency,
    String? logMessage,
  }) : super(logMessage);
}

/// The catch-all.
///
/// Carries the raw reason in `logMessage` for diagnosis only — the translation
/// deliberately ignores it and returns a generic message.
final class BuyUnexpectedFailure extends BuyFailure {
  const BuyUnexpectedFailure([super.logMessage]);
}
