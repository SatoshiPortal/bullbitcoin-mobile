import 'package:primitives/primitives.dart';

sealed class RecoverBullFailure extends Failure {
  const RecoverBullFailure([super.logMessage]);
}

final class SelectVaultFailure extends RecoverBullFailure {
  const SelectVaultFailure();
}

final class PasswordNotSetFailure extends RecoverBullFailure {
  const PasswordNotSetFailure();
}

final class VaultNotSetFailure extends RecoverBullFailure {
  const VaultNotSetFailure();
}

final class KeyServerConnectionFailure extends RecoverBullFailure {
  const KeyServerConnectionFailure();
}

final class VaultCreationFailure extends RecoverBullFailure {
  const VaultCreationFailure();
}

/// The key is already on the server; only the selected provider save failed.
final class VaultProviderSaveFailure extends RecoverBullFailure {
  const VaultProviderSaveFailure();
}

final class TorNotStartedFailure extends RecoverBullFailure {
  const TorNotStartedFailure();
}

final class ExternalTorProxyUnavailableFailure extends RecoverBullFailure {
  const ExternalTorProxyUnavailableFailure();
}

final class VaultKeyFetchFailure extends RecoverBullFailure {
  const VaultKeyFetchFailure();
}

final class VaultDecryptionFailure extends RecoverBullFailure {
  const VaultDecryptionFailure();
}

final class VaultRecoveryFailure extends RecoverBullFailure {
  const VaultRecoveryFailure();
}

final class InvalidVaultCredentialsFailure extends RecoverBullFailure {
  const InvalidVaultCredentialsFailure();
}

final class InvalidVaultFileFormatFailure extends RecoverBullFailure {
  const InvalidVaultFileFormatFailure();
}

final class VaultRateLimitedFailure extends RecoverBullFailure {
  final Duration retryIn;
  const VaultRateLimitedFailure({required this.retryIn});
}

final class RecoverBullUnexpectedFailure extends RecoverBullFailure {
  const RecoverBullUnexpectedFailure([super.logMessage]);
}
