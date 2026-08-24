import 'package:bb_mobile/core/failures/failure.dart';

sealed class SeedFailure extends Failure {
  const SeedFailure([super.logMessage]);
}

final class SeedFetchFailure extends SeedFailure {
  const SeedFetchFailure([super.logMessage]);
}

final class DefaultSeedWalletLookupFailure extends SeedFailure {
  const DefaultSeedWalletLookupFailure();
}

final class DefaultSeedNotFoundFailure extends SeedFailure {
  const DefaultSeedNotFoundFailure();
}

final class DefaultSeedAmbiguousFailure extends SeedFailure {
  const DefaultSeedAmbiguousFailure();
}

final class DefaultSeedUnavailableFailure extends SeedFailure {
  const DefaultSeedUnavailableFailure();
}

final class DefaultSeedFingerprintMismatchFailure extends SeedFailure {
  const DefaultSeedFingerprintMismatchFailure();
}

final class SeedDeleteFailure extends SeedFailure {
  const SeedDeleteFailure([super.logMessage]);
}
