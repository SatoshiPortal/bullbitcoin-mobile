import 'package:bb_mobile/core/failures/failure.dart';

sealed class ExchangeAccessFailure extends Failure {
  const ExchangeAccessFailure([super.logMessage]);
}

final class ExchangeAccessStorageFailure extends ExchangeAccessFailure {
  const ExchangeAccessStorageFailure();
}

final class ExchangeAccessInvalidFormatFailure extends ExchangeAccessFailure {
  const ExchangeAccessInvalidFormatFailure();
}

final class ExchangeAccessUnresolvedFailure extends ExchangeAccessFailure {
  const ExchangeAccessUnresolvedFailure();
}

final class ExchangeAccessIncompleteFailure extends ExchangeAccessFailure {
  const ExchangeAccessIncompleteFailure();
}
