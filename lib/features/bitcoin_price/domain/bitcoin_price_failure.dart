import 'package:primitives/primitives.dart' show Failure;

sealed class PriceChartFailure extends Failure {
  const PriceChartFailure([super.logMessage]);
}

final class PriceChartLoadFailure extends PriceChartFailure {
  const PriceChartLoadFailure();
}

final class PriceChartUnexpectedFailure extends PriceChartFailure {
  const PriceChartUnexpectedFailure([super.logMessage]);
}
