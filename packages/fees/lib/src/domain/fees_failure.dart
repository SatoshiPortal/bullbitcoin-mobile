import 'package:primitives/primitives.dart';

sealed class FeesFailure extends Failure {
  const FeesFailure();
}

final class FeeEstimateUnavailableFailure extends FeesFailure {
  const FeeEstimateUnavailableFailure();
}

final class FeeSourceReadFailure extends FeesFailure {
  const FeeSourceReadFailure();
}

final class FeeSourceWriteFailure extends FeesFailure {
  const FeeSourceWriteFailure();
}
