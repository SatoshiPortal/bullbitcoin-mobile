import 'package:bb_mobile/core/failures/failure.dart';

sealed class ExchangeApiFailure extends Failure {
  const ExchangeApiFailure(super.logMessage);
}

final class ExchangeApiNetworkFailure extends ExchangeApiFailure {
  const ExchangeApiNetworkFailure() : super('Exchange API connection failed');
}

final class ExchangeApiTimeoutFailure extends ExchangeApiFailure {
  const ExchangeApiTimeoutFailure() : super('Exchange API timed out');
}

final class ExchangeApiOutcomeUnknownFailure extends ExchangeApiFailure {
  const ExchangeApiOutcomeUnknownFailure()
    : super('Exchange order outcome unknown');
}

final class ExchangeApiUnauthenticatedFailure extends ExchangeApiFailure {
  const ExchangeApiUnauthenticatedFailure()
    : super('Exchange API authentication required');
}

final class ExchangeApiValidationFailure extends ExchangeApiFailure {
  const ExchangeApiValidationFailure()
    : super('Exchange API validation failed');
}

final class ExchangeApiMaintenanceFailure extends ExchangeApiFailure {
  const ExchangeApiMaintenanceFailure() : super('Exchange API maintenance');
}

final class ExchangeApiUnexpectedFailure extends ExchangeApiFailure {
  const ExchangeApiUnexpectedFailure() : super('Exchange API request failed');
}
