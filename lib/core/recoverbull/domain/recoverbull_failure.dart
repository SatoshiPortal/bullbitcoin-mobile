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

/// Why the key server could not be reached, as far as the transport can tell.
enum KeyServerUnreachableCause {
  /// Tor did not reach the onion service within the connect budget, or the whole attempt ran out of time.
  circuitTimeout,

  /// Tor could not build a circuit.
  torNetworkUnreachable,

  /// The onion service could not be reached: the descriptor fetch or the rendezvous failed.
  onionUnreachable,

  /// The server refused or closed the stream.
  connectionRefused,

  /// The local Tor session stopped answering.
  proxyGone,

  /// The server answered with an HTTP error status.
  httpError,

  /// The server was reached but the exchange failed or its answer was invalid.
  badResponse,

  /// No specific reason could be determined.
  unknown,
}

/// Key server unreachable or erroring (HTTP 5xx, no code, transport/Tor).
final class KeyServerUnavailableFailure extends RecoverBullCoreFailure {
  final KeyServerUnreachableCause cause;

  /// The HTTP status when [cause] is [KeyServerUnreachableCause.httpError].
  final int? httpStatus;

  const KeyServerUnavailableFailure([super.logMessage])
    : cause = KeyServerUnreachableCause.unknown,
      httpStatus = null;

  const KeyServerUnavailableFailure.because(
    this.cause, {
    this.httpStatus,
    String? logMessage,
  }) : super(logMessage);
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
