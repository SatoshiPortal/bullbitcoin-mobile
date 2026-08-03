import 'package:bb_mobile/core/failures/failure.dart';

sealed class LegacySeedViewFailure extends Failure {
  const LegacySeedViewFailure([super.logMessage]);
}

final class LegacySeedViewFetchFailure extends LegacySeedViewFailure {
  const LegacySeedViewFetchFailure([super.logMessage]);
}

final class LegacySeedViewUnexpectedFailure extends LegacySeedViewFailure {
  const LegacySeedViewUnexpectedFailure([super.logMessage]);
}
