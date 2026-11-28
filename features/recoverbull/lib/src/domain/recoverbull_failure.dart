import 'package:primitives/primitives.dart';

sealed class RecoverBullFailure extends Failure {
  const RecoverBullFailure();
}

final class VaultPassphraseRequiredFailure extends RecoverBullFailure {
  const VaultPassphraseRequiredFailure();
}

final class VaultPassphraseAcknowledgementFailure extends RecoverBullFailure {
  const VaultPassphraseAcknowledgementFailure();
}

final class VaultInvalidFailure extends RecoverBullFailure {
  const VaultInvalidFailure();
}

final class VaultPasskeyUnavailableFailure extends RecoverBullFailure {
  const VaultPasskeyUnavailableFailure();
}

/// The key, from the server or typed in, does not open this vault.
final class VaultDecryptionFailure extends RecoverBullFailure {
  const VaultDecryptionFailure();
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

/// Why the key server could not be reached, as far as the transport can tell.
enum KeyServerUnreachableCause {
  /// Tor did not reach the onion service in time.
  circuitTimeout,

  /// Tor could not build a circuit.
  torNetworkUnreachable,

  /// The descriptor fetch or the rendezvous failed.
  onionUnreachable,

  /// The server refused or closed the stream.
  connectionRefused,

  /// The local Tor session stopped answering.
  proxyGone,

  /// The server answered with an HTTP error status.
  httpError,

  /// The server was reached but its answer was invalid.
  badResponse,
}

final class KeyServerFailure extends RecoverBullFailure {
  final KeyServerFailureKind kind;
  final Duration? retryAfter;

  /// Null when the transport could not tell.
  final KeyServerUnreachableCause? cause;

  /// Set when [cause] is [KeyServerUnreachableCause.httpError].
  final int? httpStatus;

  const KeyServerFailure(
    this.kind, {
    this.retryAfter,
    this.cause,
    this.httpStatus,
  });
}

/// The user-configured Tor proxy does not answer.
final class ExternalTorProxyUnavailableFailure extends RecoverBullFailure {
  const ExternalTorProxyUnavailableFailure();
}

final class RecoverBullStorageFullFailure extends RecoverBullFailure {
  const RecoverBullStorageFullFailure();
}

final class RecoverBullStorageDamagedFailure extends RecoverBullFailure {
  const RecoverBullStorageDamagedFailure();
}

final class RecoverBullJournalFailure extends RecoverBullFailure {
  const RecoverBullJournalFailure();
}
