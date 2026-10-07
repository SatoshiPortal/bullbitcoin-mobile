import 'entities/tor_connection_state.dart';

/// A modeled, recoverable Tor failure. [logMessage] is never user-facing.
sealed class TorFailure {
  final String? logMessage;

  const TorFailure([this.logMessage]);
}

/// What the probe of a user-managed SOCKS5 proxy ran into.
enum TorExternalProxyProblem {
  /// Nothing accepted the connection: the proxy is not running, or listens on
  /// another port.
  refused,

  /// The port did not connect, or did not answer the greeting, in time.
  timeout,

  /// Something answered on the port, but not as an unauthenticated SOCKS5
  /// proxy.
  notSocks5,

  /// No probe ran, or it failed in a way none of the above describes.
  unknown,
}

final class TorExternalProxyUnavailableFailure extends TorFailure {
  final TorExternalProxyProblem problem;

  const TorExternalProxyUnavailableFailure([
    super.logMessage,
    this.problem = TorExternalProxyProblem.unknown,
  ]);
}

final class TorBootstrapFailure extends TorFailure {
  final TorDiagnostic? diagnostic;

  /// What arti last said before giving up; see [TorBootstrapDetail].
  final TorBootstrapDetail? detail;

  const TorBootstrapFailure([super.logMessage, this.diagnostic, this.detail]);
}

final class TorBootstrapTimeoutFailure extends TorFailure {
  const TorBootstrapTimeoutFailure([super.logMessage]);
}

final class TorStorageFailure extends TorFailure {
  const TorStorageFailure([super.logMessage]);
}

final class TorUnexpectedFailure extends TorFailure {
  const TorUnexpectedFailure([super.logMessage]);
}

/// Infrastructure ports throw this; the repository converts it back to state.
final class TorBackendException implements Exception {
  final TorFailure failure;

  const TorBackendException(this.failure);
}
