import 'package:bb_mobile/core/failures/failure.dart';

/// Closed set of every failure the RecoverBull core layer surfaces across its
/// boundary (the repositories). Foreign errors — key-server (`KeyServerException`),
/// vault decryption (`EncryptionException`/`RecoverBullException`), Google Drive,
/// file I/O — are caught in the repository, logged raw, and mapped to one of
/// these variants; the raw reason stays in [Failure.logMessage] (logs only).
///
/// Pure Dart, no Flutter and no SDK types. A consuming feature lifts these into
/// its own `<Feature>Failure` for translation — core never reaches the UI
/// untranslated.
sealed class RecoverBullCoreFailure extends Failure {
  const RecoverBullCoreFailure([super.logMessage]);
}

final class ExternalTorProxyUnavailableFailure extends RecoverBullCoreFailure {
  const ExternalTorProxyUnavailableFailure([super.logMessage]);
}

/// Key server rejected the credentials (HTTP 401).
final class KeyServerInvalidCredentialsFailure extends RecoverBullCoreFailure {
  const KeyServerInvalidCredentialsFailure([super.logMessage]);
}

/// Key server rate-limited the request (HTTP 429). [retryIn] is the remaining
/// cooldown when the server provided it, else null.
final class KeyServerRateLimitedFailure extends RecoverBullCoreFailure {
  final Duration? retryIn;
  const KeyServerRateLimitedFailure({this.retryIn, String? logMessage})
    : super(logMessage);
}

/// Key server rejected the request with a client error (HTTP 4xx, not 401/429).
final class KeyServerRejectedFailure extends RecoverBullCoreFailure {
  const KeyServerRejectedFailure([super.logMessage]);
}

/// Key server unreachable or erroring (HTTP 5xx, no code, transport/Tor).
final class KeyServerUnavailableFailure extends RecoverBullCoreFailure {
  const KeyServerUnavailableFailure([super.logMessage]);
}

/// The selected/fetched file is not a valid encrypted vault.
final class InvalidVaultFileFailure extends RecoverBullCoreFailure {
  const InvalidVaultFileFailure([super.logMessage]);
}

/// Catch-all (decrypt failure, Google Drive, file I/O, raw-string throws).
/// [logMessage] is for logs ONLY and MUST never reach the UI.
final class RecoverBullUnexpectedCoreFailure extends RecoverBullCoreFailure {
  const RecoverBullUnexpectedCoreFailure([super.logMessage]);
}
