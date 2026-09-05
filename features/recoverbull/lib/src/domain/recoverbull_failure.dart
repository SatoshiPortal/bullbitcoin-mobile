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

/// The key is already on the server; only the selected provider save failed.
final class VaultProviderSaveFailure extends RecoverBullFailure {
  const VaultProviderSaveFailure();
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

final class ExternalTorProxyUnavailableFailure extends RecoverBullFailure {
  const ExternalTorProxyUnavailableFailure([super.logMessage]);
}

final class KeyServerInvalidCredentialsFailure extends RecoverBullFailure {
  const KeyServerInvalidCredentialsFailure([super.logMessage]);
}

final class KeyServerRateLimitedFailure extends RecoverBullFailure {
  final Duration? retryIn;
  const KeyServerRateLimitedFailure({this.retryIn, String? logMessage})
    : super(logMessage);
}

final class KeyServerRejectedFailure extends RecoverBullFailure {
  const KeyServerRejectedFailure([super.logMessage]);
}

final class KeyServerUnavailableFailure extends RecoverBullFailure {
  const KeyServerUnavailableFailure([super.logMessage]);
}

/// Internal health probe deadline; callers map it to the normal connection UI.
final class KeyServerHealthCheckTimeoutFailure extends RecoverBullFailure {
  const KeyServerHealthCheckTimeoutFailure();
}

/// The key server is reachable but temporarily unable to serve health checks.
final class RecoverBullTemporarilyUnavailableFailure
    extends RecoverBullFailure {
  const RecoverBullTemporarilyUnavailableFailure([super.logMessage]);
}

final class InvalidVaultFileFailure extends RecoverBullFailure {
  const InvalidVaultFileFailure([super.logMessage]);
}

final class RecoverBullGoogleDriveFetchFailure extends RecoverBullFailure {
  const RecoverBullGoogleDriveFetchFailure([super.logMessage]);
}

final class RecoverBullGoogleDriveDeleteFailure extends RecoverBullFailure {
  const RecoverBullGoogleDriveDeleteFailure([super.logMessage]);
}

final class RecoverBullGoogleDriveExportFailure extends RecoverBullFailure {
  const RecoverBullGoogleDriveExportFailure([super.logMessage]);
}

final class RecoverBullUnexpectedFailure extends RecoverBullFailure {
  const RecoverBullUnexpectedFailure([super.logMessage]);
}
