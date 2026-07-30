import 'entities/tor_connection_state.dart';

/// A modeled, recoverable Tor failure. [logMessage] is never user-facing.
sealed class TorFailure {
  final String? logMessage;

  const TorFailure([this.logMessage]);
}

final class TorExternalProxyUnavailableFailure extends TorFailure {
  const TorExternalProxyUnavailableFailure([super.logMessage]);
}

final class TorBootstrapFailure extends TorFailure {
  final TorDiagnostic? diagnostic;

  const TorBootstrapFailure([super.logMessage, this.diagnostic]);
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
