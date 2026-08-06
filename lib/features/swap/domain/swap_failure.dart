import 'package:bb_mobile/core/failures/failure.dart';

sealed class SwapFailure extends Failure {
  const SwapFailure([super.logMessage]);
}

final class SwapNoPaymentOptionFailure extends SwapFailure {
  const SwapNoPaymentOptionFailure([super.logMessage]);
}

final class SwapAmountOutOfBoundsFailure extends SwapFailure {
  final BigInt? limitAmountSat;
  final bool? isMinimum;

  const SwapAmountOutOfBoundsFailure({
    this.limitAmountSat,
    this.isMinimum,
    String? logMessage,
  }) : super(logMessage);
}

final class SwapValidationFailure extends SwapFailure {
  final String? field;

  const SwapValidationFailure({this.field, String? logMessage})
    : super(logMessage);
}

final class SwapOrderNotFoundFailure extends SwapFailure {
  const SwapOrderNotFoundFailure([super.logMessage]);
}

final class SwapOrderExpiredFailure extends SwapFailure {
  const SwapOrderExpiredFailure([super.logMessage]);
}

final class SwapCreationUnknownFailure extends SwapFailure {
  const SwapCreationUnknownFailure([super.logMessage]);
}

final class SwapInvalidStateFailure extends SwapFailure {
  const SwapInvalidStateFailure([super.logMessage]);
}

final class SwapRateLimitedFailure extends SwapFailure {
  final Duration? retryAfter;

  const SwapRateLimitedFailure({this.retryAfter, String? logMessage})
    : super(logMessage);
}

final class SwapProviderFailure extends SwapFailure {
  const SwapProviderFailure([super.logMessage]);
}

final class SwapNetworkFailure extends SwapFailure {
  const SwapNetworkFailure([super.logMessage]);
}

final class SwapTimeoutFailure extends SwapFailure {
  const SwapTimeoutFailure([super.logMessage]);
}

final class SwapStorageFailure extends SwapFailure {
  const SwapStorageFailure([super.logMessage]);
}

final class SwapUnexpectedFailure extends SwapFailure {
  const SwapUnexpectedFailure([super.logMessage]);
}
