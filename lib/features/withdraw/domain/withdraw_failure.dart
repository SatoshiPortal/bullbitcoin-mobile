import 'package:bb_mobile/core/failures/failure.dart';

sealed class WithdrawFailure extends Failure {
  const WithdrawFailure([super.logMessage]);
}

final class WithdrawUnauthenticatedFailure extends WithdrawFailure {
  const WithdrawUnauthenticatedFailure([super.logMessage]);
}

final class WithdrawBelowMinAmountFailure extends WithdrawFailure {
  final double minAmount;
  final String currency;

  const WithdrawBelowMinAmountFailure({
    required this.minAmount,
    required this.currency,
    String? logMessage,
  }) : super(logMessage);
}

final class WithdrawAboveMaxAmountFailure extends WithdrawFailure {
  final double maxAmount;
  final String currency;

  const WithdrawAboveMaxAmountFailure({
    required this.maxAmount,
    required this.currency,
    String? logMessage,
  }) : super(logMessage);
}

final class WithdrawOrderNotFoundFailure extends WithdrawFailure {
  const WithdrawOrderNotFoundFailure([super.logMessage]);
}

final class WithdrawOrderAlreadyConfirmedFailure extends WithdrawFailure {
  const WithdrawOrderAlreadyConfirmedFailure([super.logMessage]);
}

final class WithdrawConfidentialSepaNotActivatedFailure
    extends WithdrawFailure {
  const WithdrawConfidentialSepaNotActivatedFailure([super.logMessage]);
}

final class WithdrawUnexpectedFailure extends WithdrawFailure {
  const WithdrawUnexpectedFailure([super.logMessage]);
}
