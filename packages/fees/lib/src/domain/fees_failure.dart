import 'package:primitives/primitives.dart';

sealed class FeesFailure extends Failure {
  const FeesFailure();
}

final class FeeEstimateUnavailableFailure extends FeesFailure {
  const FeeEstimateUnavailableFailure();
}
