import 'package:primitives/primitives.dart' show Failure;

/// Why the pricer could not provide a price.
sealed class PricerFailure extends Failure {
  const PricerFailure([super.logMessage]);
}

/// The price service could not be reached, or did not answer successfully.
final class PricerNetworkFailure extends PricerFailure {
  const PricerNetworkFailure([super.logMessage]);
}

/// The price service only exists for mainnet and testnet.
final class PricerUnsupportedNetworkFailure extends PricerFailure {
  const PricerUnsupportedNetworkFailure([super.logMessage]);
}

/// The price service refused the request because too many were sent.
final class PricerRateLimitedFailure extends PricerFailure {
  const PricerRateLimitedFailure([super.logMessage]);
}

/// The price service answered with something that is not a usable price.
final class PricerUnexpectedFailure extends PricerFailure {
  const PricerUnexpectedFailure([super.logMessage]);
}
