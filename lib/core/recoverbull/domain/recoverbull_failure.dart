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

/// The targeted per-identifier lockout (HTTP 429). [retryIn] is the remaining
/// cooldown when the server provided it, else null.
///
/// The key server emits 429 from exactly one place: the per-identifier
/// rate-limit bucket. Every service-wide bucket (lookup, store, `/attempts`)
/// answers 503 instead, and the reverse proxy converts its own edge 429 into
/// 503 too, so a 429 always means "this identifier is locked out" and never
/// "the server is busy". On the user's own fetch it is therefore an alarm
/// signal: someone may be probing or griefing this backup.
final class KeyServerRateLimitedFailure extends RecoverBullCoreFailure {
  final Duration? retryIn;
  const KeyServerRateLimitedFailure({this.retryIn, String? logMessage})
    : super(logMessage);
}

/// Key server rejected the request with a client error (HTTP 4xx, not 401/429).
final class KeyServerRejectedFailure extends RecoverBullCoreFailure {
  const KeyServerRejectedFailure([super.logMessage]);
}

/// The key server explicitly reports service-wide pressure (HTTP 503): an
/// exhausted global bucket, a full rate-limit map, or the reverse proxy's own
/// edge limit, which the deployment rewrites to 503.
///
/// Never an attack signal — and distinct from [KeyServerUnavailableFailure]
/// because only this one lets the UI truthfully say "the server is busy". A
/// server we simply could not reach must not be described as overloaded.
final class KeyServerBusyFailure extends RecoverBullCoreFailure {
  const KeyServerBusyFailure([super.logMessage]);
}

/// Key server unreachable or erroring (other 5xx, no code, transport/Tor).
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
