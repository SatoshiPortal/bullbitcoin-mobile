import 'package:bb_mobile/core/failures/failure.dart';

sealed class SendFailure extends Failure {
  const SendFailure([super.logMessage]);
}

final class SendInvalidPaymentRequestFailure extends SendFailure {
  final bool isUnsupportedQr;

  const SendInvalidPaymentRequestFailure({
    this.isUnsupportedQr = false,
    String? logMessage,
  }) : super(logMessage);
}

final class SendInvoiceExpiredFailure extends SendFailure {
  const SendInvoiceExpiredFailure([super.logMessage]);
}

final class SendInvoiceAmountRequiredFailure extends SendFailure {
  const SendInvoiceAmountRequiredFailure([super.logMessage]);
}

final class SendHardwareWalletFailure extends SendFailure {
  const SendHardwareWalletFailure([super.logMessage]);
}

final class SendInsufficientBalanceFailure extends SendFailure {
  const SendInsufficientBalanceFailure([super.logMessage]);
}

final class SendAmountOutOfBoundsFailure extends SendFailure {
  final BigInt? minimumSat;
  final BigInt? maximumSat;
  final bool suggestInstantPayments;

  const SendAmountOutOfBoundsFailure({
    this.minimumSat,
    this.maximumSat,
    this.suggestInstantPayments = false,
    String? logMessage,
  }) : super(logMessage);
}

final class SendSwapCreationFailure extends SendFailure {
  const SendSwapCreationFailure([super.logMessage]);
}

final class SendRateLimitedFailure extends SendFailure {
  final Duration? retryAfter;

  const SendRateLimitedFailure({this.retryAfter, String? logMessage})
    : super(logMessage);
}

final class SendTransactionBuildFailure extends SendFailure {
  const SendTransactionBuildFailure([super.logMessage]);
}

final class SendTransactionConfirmationFailure extends SendFailure {
  final bool isBroadcastFailure;

  const SendTransactionConfirmationFailure({
    this.isBroadcastFailure = false,
    String? logMessage,
  }) : super(logMessage);
}

final class SendUnexpectedFailure extends SendFailure {
  const SendUnexpectedFailure([super.logMessage]);
}
