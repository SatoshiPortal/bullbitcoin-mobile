import 'package:bb_mobile/core/failures/failure.dart';

sealed class SellFailure extends Failure {
  const SellFailure([super.logMessage]);
}

final class SellUnauthenticatedFailure extends SellFailure {
  const SellUnauthenticatedFailure();
}

final class SellBelowMinAmountFailure extends SellFailure {
  final int minAmountSat;
  const SellBelowMinAmountFailure({
    required this.minAmountSat,
    String? logMessage,
  }) : super(logMessage);
}

final class SellAboveMaxAmountFailure extends SellFailure {
  final int maxAmountSat;
  const SellAboveMaxAmountFailure({
    required this.maxAmountSat,
    String? logMessage,
  }) : super(logMessage);
}

final class SellInsufficientBalanceFailure extends SellFailure {
  final int requiredAmountSat;
  const SellInsufficientBalanceFailure({
    required this.requiredAmountSat,
    String? logMessage,
  }) : super(logMessage);
}

final class SellPrepareTransactionFailure extends SellFailure {
  const SellPrepareTransactionFailure([super.logMessage]);
}

final class SellSendPaymentFailure extends SellFailure {
  const SellSendPaymentFailure([super.logMessage]);
}

final class SellLoadUtxosFailure extends SellFailure {
  const SellLoadUtxosFailure([super.logMessage]);
}

/// Catch-all. [logMessage] is for logs/Sentry ONLY and MUST never reach the UI.
final class SellUnexpectedFailure extends SellFailure {
  const SellUnexpectedFailure([super.logMessage]);
}
