import 'package:primitives/primitives.dart';

/// Closed set of every failure the RecoverBull (vault backup/restore) flow
/// surfaces to the user.
///
/// Foreign errors (key-server, Tor, Google Drive, decryption SDK) are caught at
/// the feature boundary — the bloc, the first layer the feature owns above the
/// still-throwing core usecases — and mapped into one of these variants; the
/// raw reason stays in the logs. `sealed` keeps it closed (exhaustive switches;
/// no foreign variants). Pure Dart — the user-facing message lives in the
/// presentation extension `recoverbull_failure_l10n.dart`, never here.
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

final class TorNotStartedFailure extends RecoverBullFailure {
  const TorNotStartedFailure();
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

/// Rate-limited by the key server. Carries [retryIn] so the UI can show the
/// remaining cooldown. Fields first, then constructor (AGENTS.md ordering).
final class VaultRateLimitedFailure extends RecoverBullFailure {
  final Duration retryIn;
  const VaultRateLimitedFailure({required this.retryIn});
}

/// Catch-all. [logMessage] is for logs ONLY and MUST never reach the UI —
/// the presentation extension returns the shared generic string.
final class RecoverBullUnexpectedFailure extends RecoverBullFailure {
  const RecoverBullUnexpectedFailure([super.logMessage]);
}

sealed class RecoverBullCoreFailure extends Failure {
  const RecoverBullCoreFailure([super.logMessage]);
}

final class ExternalTorProxyUnavailableFailure extends RecoverBullCoreFailure {
  const ExternalTorProxyUnavailableFailure([super.logMessage]);
}

final class KeyServerInvalidCredentialsFailure extends RecoverBullCoreFailure {
  const KeyServerInvalidCredentialsFailure([super.logMessage]);
}

final class KeyServerRateLimitedFailure extends RecoverBullCoreFailure {
  final Duration? retryIn;
  const KeyServerRateLimitedFailure({this.retryIn, String? logMessage})
    : super(logMessage);
}

final class KeyServerRejectedFailure extends RecoverBullCoreFailure {
  const KeyServerRejectedFailure([super.logMessage]);
}

final class KeyServerUnavailableFailure extends RecoverBullCoreFailure {
  const KeyServerUnavailableFailure([super.logMessage]);
}

final class InvalidVaultFileFailure extends RecoverBullCoreFailure {
  const InvalidVaultFileFailure([super.logMessage]);
}

final class RecoverBullUnexpectedCoreFailure extends RecoverBullCoreFailure {
  const RecoverBullUnexpectedCoreFailure([super.logMessage]);
}
