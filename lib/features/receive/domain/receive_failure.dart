import 'package:bb_mobile/core/failures/failure.dart';
import 'package:bb_mobile/core/primitives/payment_network.dart';

sealed class ReceiveFailure extends Failure {
  const ReceiveFailure([super.logMessage]);
}

final class ReceiveAmountOutOfBoundsFailure extends ReceiveFailure {
  final BigInt? limitAmountSat;
  final bool? isMinimum;

  const ReceiveAmountOutOfBoundsFailure({
    this.limitAmountSat,
    this.isMinimum,
    String? logMessage,
  }) : super(logMessage);
}

final class ReceiveInvalidInvoiceFailure extends ReceiveFailure {
  const ReceiveInvalidInvoiceFailure([super.logMessage]);
}

final class ReceiveSwapUnavailableFailure extends ReceiveFailure {
  const ReceiveSwapUnavailableFailure([super.logMessage]);
}

final class ReceiveSwapRouteUnavailableFailure extends ReceiveFailure {
  final PaymentNetwork? inNetwork;
  final PaymentNetwork? outNetwork;

  const ReceiveSwapRouteUnavailableFailure({
    this.inNetwork,
    this.outNetwork,
    String? logMessage,
  }) : super(logMessage);
}

final class ReceiveNetworkFailure extends ReceiveFailure {
  const ReceiveNetworkFailure([super.logMessage]);
}

final class ReceiveRateLimitedFailure extends ReceiveFailure {
  final Duration? retryAfter;

  const ReceiveRateLimitedFailure({this.retryAfter, String? logMessage})
    : super(logMessage);
}

final class ReceiveUnexpectedFailure extends ReceiveFailure {
  const ReceiveUnexpectedFailure([super.logMessage]);
}
