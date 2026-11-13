import 'package:primitives/primitives.dart' show Failure;

/// Recoverable failures while reading exchange orders for history/enrichment.
sealed class ExchangeOrderFailure extends Failure {
  const ExchangeOrderFailure([super.logMessage]);
}

final class ExchangeOrderCredentialFailure extends ExchangeOrderFailure {
  const ExchangeOrderCredentialFailure();
}

final class ExchangeOrderLoadFailure extends ExchangeOrderFailure {
  const ExchangeOrderLoadFailure();
}
