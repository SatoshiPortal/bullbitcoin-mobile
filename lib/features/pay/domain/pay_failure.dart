import 'package:bb_mobile/core/failures/failure.dart';

sealed class PayFailure extends Failure {
  const PayFailure([super.logMessage]);
}

/// The API rejected the request because the session is not (or no longer)
/// authenticated.
final class PayUnauthenticatedFailure extends PayFailure {
  const PayUnauthenticatedFailure([super.logMessage]);
}

/// The amount is under the minimum this recipient can be paid.
///
/// [minAmount] is denominated in [currency], which the API picks and can be
/// either a fiat currency or BTC/LBTC.
final class PayBelowMinAmountFailure extends PayFailure {
  final double minAmount;
  final String currency;

  const PayBelowMinAmountFailure({
    required this.minAmount,
    required this.currency,
    String? logMessage,
  }) : super(logMessage);
}

/// The amount is over the maximum this recipient can be paid. See
/// [PayBelowMinAmountFailure] for how [currency] is chosen.
final class PayAboveMaxAmountFailure extends PayFailure {
  final double maxAmount;
  final String currency;

  const PayAboveMaxAmountFailure({
    required this.maxAmount,
    required this.currency,
    String? logMessage,
  }) : super(logMessage);
}

/// A price-lock refresh came back with a different deposit address than the
/// order was created with. That must never happen in correct backend
/// operation, so the refreshed order is refused rather than paid.
final class PayDepositAddressChangedFailure extends PayFailure {
  const PayDepositAddressChangedFailure([super.logMessage]);
}

/// The selected wallet cannot cover [requiredAmountSat] plus fees.
///
/// Reachable because the Liquid prepare step rethrows the insufficient-funds
/// family rather than wrapping it; before this family existed those landed in
/// the catch-all and printed the wallet's own words on screen.
final class PayInsufficientBalanceFailure extends PayFailure {
  final int requiredAmountSat;

  const PayInsufficientBalanceFailure({
    required this.requiredAmountSat,
    String? logMessage,
  }) : super(logMessage);
}

/// The payin was built but its fee lands under the network relay floor, so no
/// node would accept it. Actionable: the user must raise the fee.
final class PayFeeBelowRelayFloorFailure extends PayFailure {
  const PayFeeBelowRelayFloorFailure([super.logMessage]);
}

/// No fee could be resolved for the payin, so it cannot be built.
final class PayFeesUnavailableFailure extends PayFailure {
  const PayFeesUnavailableFailure([super.logMessage]);
}

/// The catch-all.
///
/// Carries the raw reason in `logMessage` for diagnosis only — the translation
/// deliberately ignores it and returns a generic message, because this is where
/// BDK/LWK/API text used to reach the screen verbatim (#1895).
final class PayUnexpectedFailure extends PayFailure {
  const PayUnexpectedFailure([super.logMessage]);
}
