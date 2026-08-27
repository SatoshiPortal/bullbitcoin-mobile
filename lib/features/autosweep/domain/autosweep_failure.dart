import 'package:bb_mobile/core/failures/failure.dart';

sealed class AutosweepFailure extends Failure {
  const AutosweepFailure();
}

final class AutosweepOperationFailure extends AutosweepFailure {
  const AutosweepOperationFailure();
}
