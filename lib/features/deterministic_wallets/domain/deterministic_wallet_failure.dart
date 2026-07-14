import 'package:bb_mobile/core/failures/failure.dart';

/// Typed failures exposed by the deterministic-wallet boundary.
///
/// Presentation code maps these types to translated copy. [logMessage], when
/// present, is diagnostic-only and must never be rendered.
sealed class DeterministicWalletFailure extends Failure {
  const DeterministicWalletFailure([super.logMessage]);
}

final class InvalidDeterministicWalletRequestFailure
    extends DeterministicWalletFailure {
  const InvalidDeterministicWalletRequestFailure();
}

final class DeterministicWalletMismatchFailure
    extends DeterministicWalletFailure {
  const DeterministicWalletMismatchFailure();
}

final class DeterministicWalletDerivationConflictFailure
    extends DeterministicWalletFailure {
  const DeterministicWalletDerivationConflictFailure();
}

final class DeterministicWalletDerivationFailure
    extends DeterministicWalletFailure {
  const DeterministicWalletDerivationFailure();
}

final class DeterministicWalletStorageFailure
    extends DeterministicWalletFailure {
  const DeterministicWalletStorageFailure();
}

final class DeterministicWalletOperationFailure
    extends DeterministicWalletFailure {
  const DeterministicWalletOperationFailure();
}

final class DeterministicWalletRollbackFailure
    extends DeterministicWalletFailure {
  const DeterministicWalletRollbackFailure();
}

final class DeterministicWalletUnexpectedFailure
    extends DeterministicWalletFailure {
  const DeterministicWalletUnexpectedFailure();
}
