import 'package:primitives/primitives.dart' show Failure;

sealed class BitcoinPriceFailure extends Failure {
  const BitcoinPriceFailure([super.logMessage]);
}

final class BitcoinPriceNetworkFailure extends BitcoinPriceFailure {
  const BitcoinPriceNetworkFailure([super.logMessage]);
}

final class BitcoinPriceRateUnavailableFailure extends BitcoinPriceFailure {
  const BitcoinPriceRateUnavailableFailure([super.logMessage]);
}

final class BitcoinPricePreferencesFailure extends BitcoinPriceFailure {
  const BitcoinPricePreferencesFailure([super.logMessage]);
}

final class BitcoinPriceUnexpectedFailure extends BitcoinPriceFailure {
  const BitcoinPriceUnexpectedFailure([super.logMessage]);
}

final class PriceChartLoadFailure extends BitcoinPriceFailure {
  const PriceChartLoadFailure();
}
