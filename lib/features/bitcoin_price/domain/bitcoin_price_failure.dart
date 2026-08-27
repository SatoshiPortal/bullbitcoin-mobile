import 'package:bb_mobile/core/failures/failure.dart';

sealed class BitcoinPriceFailure extends Failure {
  const BitcoinPriceFailure([super.logMessage]);
}

final class BitcoinPriceInvalidRateFailure extends BitcoinPriceFailure {
  const BitcoinPriceInvalidRateFailure();
}

final class BitcoinPriceUnexpectedFailure extends BitcoinPriceFailure {
  const BitcoinPriceUnexpectedFailure([super.logMessage]);
}

sealed class PriceChartFailure extends Failure {
  const PriceChartFailure([super.logMessage]);
}

final class PriceChartLoadFailure extends PriceChartFailure {
  const PriceChartLoadFailure();
}

final class PriceChartUnexpectedFailure extends PriceChartFailure {
  const PriceChartUnexpectedFailure([super.logMessage]);
}
