import 'package:bb_mobile/core/failures/failure.dart';

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

final class VaultStatusPersistenceFailure extends RecoverBullFailure {
  const VaultStatusPersistenceFailure([super.logMessage]);
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
