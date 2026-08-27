import 'package:bb_mobile/core/failures/failure.dart';

sealed class SeedFailure extends Failure {
  const SeedFailure([super.logMessage]);
}

final class SeedFetchFailure extends SeedFailure {
  const SeedFetchFailure([super.logMessage]);
}

final class SeedDeleteFailure extends SeedFailure {
  const SeedDeleteFailure([super.logMessage]);
}
