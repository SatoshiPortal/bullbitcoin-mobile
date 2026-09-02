import 'package:bb_mobile/core/failures/failure.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';

sealed class Bip85Failure extends Failure {
  const Bip85Failure([super.logMessage]);
}

final class Bip85NoDefaultWalletFailure extends Bip85Failure {
  const Bip85NoDefaultWalletFailure([super.logMessage]);
}

final class Bip85DefaultWalletAmbiguousFailure extends Bip85Failure {
  const Bip85DefaultWalletAmbiguousFailure([super.logMessage]);
}

final class Bip85DerivationFailure extends Bip85Failure {
  const Bip85DerivationFailure([super.logMessage]);
}

final class Bip85DerivationConflictFailure extends Bip85Failure {
  const Bip85DerivationConflictFailure([super.logMessage]);
}

final class Bip85StorageFailure extends Bip85Failure {
  const Bip85StorageFailure([super.logMessage]);
}

final class Bip85UnexpectedFailure extends Bip85Failure {
  const Bip85UnexpectedFailure([super.logMessage]);
}

Bip85Failure bip85FailureFromDefaultSeed(SeedFailure failure) =>
    switch (failure) {
      DefaultSeedNotFoundFailure() => const Bip85NoDefaultWalletFailure(),
      DefaultSeedAmbiguousFailure() =>
        const Bip85DefaultWalletAmbiguousFailure(),
      _ => const Bip85UnexpectedFailure('Default seed unavailable'),
    };
