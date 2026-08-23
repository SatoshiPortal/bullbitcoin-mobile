import 'package:bb_mobile/core/failures/failure.dart';

sealed class DeterministicWalletFailure extends Failure {
  const DeterministicWalletFailure();
}

final class InvalidDeterministicWalletRequestFailure
    extends DeterministicWalletFailure {
  const InvalidDeterministicWalletRequestFailure();
}

final class DeterministicWalletMismatchFailure
    extends DeterministicWalletFailure {
  const DeterministicWalletMismatchFailure();
}

final class DeterministicWalletDerivationFailure
    extends DeterministicWalletFailure {
  const DeterministicWalletDerivationFailure();
}

final class DeterministicWalletDerivationConflictFailure
    extends DeterministicWalletFailure {
  const DeterministicWalletDerivationConflictFailure();
}

final class DeterministicWalletOperationFailure
    extends DeterministicWalletFailure {
  const DeterministicWalletOperationFailure();
}

final class DeterministicWalletRollbackFailure
    extends DeterministicWalletFailure {
  const DeterministicWalletRollbackFailure();
}
