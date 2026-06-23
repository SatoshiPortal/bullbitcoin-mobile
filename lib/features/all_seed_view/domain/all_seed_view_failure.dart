import 'package:bb_mobile/core/failures/failure.dart';

sealed class AllSeedViewFailure extends Failure {
  const AllSeedViewFailure([super.logMessage]);
}

final class AllSeedViewFetchFailure extends AllSeedViewFailure {
  const AllSeedViewFetchFailure([super.logMessage]);
}

final class AllSeedViewDeleteFailure extends AllSeedViewFailure {
  const AllSeedViewDeleteFailure([super.logMessage]);
}

final class AllSeedViewUnexpectedFailure extends AllSeedViewFailure {
  const AllSeedViewUnexpectedFailure([super.logMessage]);
}
