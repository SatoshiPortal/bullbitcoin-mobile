import 'package:primitives/primitives.dart';

sealed class RecoverBullFailure extends Failure {
  const RecoverBullFailure();
}

final class VaultInvalidFailure extends RecoverBullFailure {
  const VaultInvalidFailure();
}

final class VaultSecretMissingFailure extends RecoverBullFailure {
  const VaultSecretMissingFailure();
}

final class VaultKeystoreLockedFailure extends RecoverBullFailure {
  const VaultKeystoreLockedFailure();
}

final class VaultStorageFailure extends RecoverBullFailure {
  const VaultStorageFailure();
}

final class VaultUnsupportedSecretFailure extends RecoverBullFailure {
  const VaultUnsupportedSecretFailure();
}

final class VaultContextChangedFailure extends RecoverBullFailure {
  const VaultContextChangedFailure();
}

final class VaultWalletMissingFailure extends RecoverBullFailure {
  const VaultWalletMissingFailure();
}

final class VaultWalletMismatchFailure extends RecoverBullFailure {
  const VaultWalletMismatchFailure();
}

final class VaultCancelledFailure extends RecoverBullFailure {
  const VaultCancelledFailure();
}

final class RecoverBullUnexpectedFailure extends RecoverBullFailure {
  const RecoverBullUnexpectedFailure();
}

enum KeyServerFailureKind {
  credentials,
  locked,
  unavailable,
  timeout,
  badResponse,
  rejected,
}

final class KeyServerFailure extends RecoverBullFailure {
  final KeyServerFailureKind kind;
  final Duration? retryAfter;

  const KeyServerFailure(this.kind, {this.retryAfter});
}
