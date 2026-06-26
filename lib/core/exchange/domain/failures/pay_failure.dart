import 'package:bb_mobile/core/failures/failure.dart';

sealed class PayFailure extends Failure {
  const PayFailure([super.logMessage]);
}

final class PayUnauthenticatedFailure extends PayFailure {
  const PayUnauthenticatedFailure();
}

final class PayBelowMinAmountFailure extends PayFailure {
  final int minAmountSat;
  const PayBelowMinAmountFailure({required this.minAmountSat});
}

final class PayAboveMaxAmountFailure extends PayFailure {
  final int maxAmountSat;
  const PayAboveMaxAmountFailure({required this.maxAmountSat});
}

final class PayInsufficientBalanceFailure extends PayFailure {
  const PayInsufficientBalanceFailure();
}

final class PayOrderNotFoundFailure extends PayFailure {
  const PayOrderNotFoundFailure();
}

final class PayOrderAlreadyConfirmedFailure extends PayFailure {
  const PayOrderAlreadyConfirmedFailure();
}

/// Catch-all. [logMessage] is for logs/Sentry ONLY and MUST never reach the UI.
final class PayUnexpectedFailure extends PayFailure {
  const PayUnexpectedFailure([super.logMessage]);
}
