import '../entities/tor_connection_state.dart';
import '../entities/tor_proxy_endpoint.dart';
import '../entities/tor_session.dart';
import '../entities/tor_transport.dart';
import '../tor_failure.dart';

sealed class EmbeddedTorEvent {
  const EmbeddedTorEvent();
}

final class EmbeddedTorConnecting extends EmbeddedTorEvent {
  final double progress;
  final TorDiagnostic? diagnostic;
  final TorTransport transport;

  const EmbeddedTorConnecting({
    required this.progress,
    required this.transport,
    this.diagnostic,
  });
}

final class EmbeddedTorReady extends EmbeddedTorEvent {
  final TorProxyEndpoint endpoint;
  final TorTransport transport;

  const EmbeddedTorReady(this.endpoint, this.transport);
}

final class EmbeddedTorStopped extends EmbeddedTorEvent {
  const EmbeddedTorStopped();
}

final class EmbeddedTorFailed extends EmbeddedTorEvent {
  final TorFailure failure;

  const EmbeddedTorFailed(this.failure);
}

abstract interface class EmbeddedTorPort {
  Stream<EmbeddedTorEvent> watch();

  Future<TorProxyEndpoint> start(TorTransport transport);

  Future<TorSession> openSession();

  Future<bool> isAlive();

  Future<void> setDormant(bool dormant);

  /// Tears the client down; [start] may be called again afterwards.
  Future<void> stop();

  /// Releases the backend for good, [watch] included. Unlike [stop] this is
  /// terminal — the owning repository calls it when it is itself closing.
  Future<void> close();
}
