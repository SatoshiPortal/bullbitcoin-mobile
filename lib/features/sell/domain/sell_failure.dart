import 'package:bb_mobile/core/failures/failure.dart';

sealed class SellFailure extends Failure {
  const SellFailure([super.logMessage]);
}

/// The API rejected the request because the session is not (or no longer)
/// authenticated.
final class SellUnauthenticatedFailure extends SellFailure {
  const SellUnauthenticatedFailure([super.logMessage]);
}

/// The amount is under the minimum this wallet can sell.
///
/// [minAmount] is denominated in [currency], which the API picks and can be
/// either a fiat currency or BTC/LBTC.
final class SellBelowMinAmountFailure extends SellFailure {
  final double minAmount;
  final String currency;

  const SellBelowMinAmountFailure({
    required this.minAmount,
    required this.currency,
    String? logMessage,
  }) : super(logMessage);
}

/// The amount is over the maximum this wallet can sell. See
/// [SellBelowMinAmountFailure] for how [currency] is chosen.
final class SellAboveMaxAmountFailure extends SellFailure {
  final double maxAmount;
  final String currency;

  const SellAboveMaxAmountFailure({
    required this.maxAmount,
    required this.currency,
    String? logMessage,
  }) : super(logMessage);
}

final class SellOrderNotFoundFailure extends SellFailure {
  const SellOrderNotFoundFailure([super.logMessage]);
}

final class SellOrderAlreadyConfirmedFailure extends SellFailure {
  const SellOrderAlreadyConfirmedFailure([super.logMessage]);
}

/// A price-lock refresh came back with a different deposit address than the
/// order was created with. That must never happen in correct backend
/// operation, so the refreshed order is refused rather than paid.
final class SellDepositAddressChangedFailure extends SellFailure {
  const SellDepositAddressChangedFailure([super.logMessage]);
}

/// The selected wallet cannot cover [requiredAmountSat] plus fees.
final class SellInsufficientBalanceFailure extends SellFailure {
  final int requiredAmountSat;

  const SellInsufficientBalanceFailure({
    required this.requiredAmountSat,
    String? logMessage,
  }) : super(logMessage);
}

/// The payin was built but its fee lands under the network relay floor, so no
/// node would accept it. Actionable: the user must raise the fee.
final class SellFeeBelowRelayFloorFailure extends SellFailure {
  const SellFeeBelowRelayFloorFailure([super.logMessage]);
}

/// The network fee rates could not be fetched, so no payin can be built.
final class SellFeesUnavailableFailure extends SellFailure {
  const SellFeesUnavailableFailure([super.logMessage]);
}

/// The catch-all.
///
/// Carries the raw reason in `logMessage` for diagnosis only — the translation
/// deliberately ignores it and returns a generic message, because this is
/// where BDK/LWK/API text used to reach the screen verbatim (#1895).
final class SellUnexpectedFailure extends SellFailure {
  const SellUnexpectedFailure([super.logMessage]);
}
