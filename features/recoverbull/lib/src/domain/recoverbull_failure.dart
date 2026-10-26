import 'package:primitives/primitives.dart';

/// Closed set of every failure the RecoverBull (vault backup/restore) flow
/// surfaces to the user.
///
/// Repositories map foreign exceptions at the data boundary; use cases compose
/// results and choose workflow failures. Presentation only translates them.
/// This sealed family is Flutter-free and never exposes raw reasons to users.
sealed class RecoverBullFailure extends Failure {
  const RecoverBullFailure([super.logMessage]);

  String? get supportCause => null;
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
  final KeyServerUnreachableCause cause;
  final int? httpStatus;
  const KeyServerConnectionFailure({
    this.cause = KeyServerUnreachableCause.unknown,
    this.httpStatus,
  });
}

final class KeyServerTorFailure extends RecoverBullFailure {
  const KeyServerTorFailure();

  @override
  String get supportCause => 'tor';
}

final class KeyServerOnionUnreachableFailure extends RecoverBullFailure {
  const KeyServerOnionUnreachableFailure();

  @override
  String get supportCause => 'onion_unreachable';
}

final class KeyServerServiceRefusedFailure extends RecoverBullFailure {
  const KeyServerServiceRefusedFailure();

  @override
  String get supportCause => 'refused';
}

final class KeyServerConnectionBudgetFailure extends RecoverBullFailure {
  const KeyServerConnectionBudgetFailure();

  @override
  String get supportCause => 'budget';
}

final class KeyServerConnectionUnknownFailure extends RecoverBullFailure {
  const KeyServerConnectionUnknownFailure();

  @override
  String get supportCause => 'unknown';
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

final class VaultBelongsToAnotherWalletFailure extends RecoverBullFailure {
  const VaultBelongsToAnotherWalletFailure();
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

final class VaultServiceBusyFailure extends RecoverBullFailure {
  final Duration? retryIn;
  const VaultServiceBusyFailure({this.retryIn});
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

final class KeyServerBusyFailure extends RecoverBullFailure {
  final Duration? retryIn;
  const KeyServerBusyFailure({this.retryIn, String? logMessage})
    : super(logMessage);
}

final class KeyServerRejectedFailure extends RecoverBullFailure {
  const KeyServerRejectedFailure([super.logMessage]);
}

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

final class KeyServerUnavailableFailure extends RecoverBullFailure {
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

/// Internal health probe deadline; callers map it to the normal connection UI.
final class KeyServerHealthCheckTimeoutFailure extends RecoverBullFailure {
  const KeyServerHealthCheckTimeoutFailure();
}

/// The key server is reachable but temporarily unable to serve health checks.
final class RecoverBullTemporarilyUnavailableFailure
    extends RecoverBullFailure {
  final Duration? retryIn;
  const RecoverBullTemporarilyUnavailableFailure({
    this.retryIn,
    String? logMessage,
  }) : super(logMessage);
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
