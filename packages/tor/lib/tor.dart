/// What features consume: Tor state, the selected route, and the operations
/// that produce them.
///
/// Wiring lives in `tor_adapter.dart` and stays out of here on purpose — a
/// feature that can reach the repository or a platform port can bypass the
/// use-cases, which is exactly the layering this split prevents.
library;

export 'src/data/tor_http_client_factory.dart';
export 'src/domain/entities/tor_connection_state.dart';
export 'src/domain/entities/tor_proxy_endpoint.dart';
export 'src/domain/entities/tor_route.dart';
export 'src/domain/entities/tor_session.dart';
export 'src/domain/entities/tor_transport.dart';
export 'src/domain/tor_failure.dart';
export 'src/domain/usecases/ensure_tor_ready_usecase.dart';
export 'src/domain/usecases/retry_tor_connection_usecase.dart';
export 'src/domain/usecases/verify_external_tor_usecase.dart';
export 'src/domain/usecases/watch_tor_connection_usecase.dart';
export 'src/tor_controller.dart';
