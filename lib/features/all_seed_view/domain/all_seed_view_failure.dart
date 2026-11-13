import 'package:primitives/primitives.dart' show Failure;

sealed class AllSeedViewFailure extends Failure {
  const AllSeedViewFailure([super.logMessage]);
}

final class AllSeedViewFetchFailure extends AllSeedViewFailure {
  const AllSeedViewFetchFailure([super.logMessage]);
}

final class AllSeedViewDeleteFailure extends AllSeedViewFailure {
  const AllSeedViewDeleteFailure([super.logMessage]);
}
