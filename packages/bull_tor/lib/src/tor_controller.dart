import 'domain/entities/tor_connection_state.dart';
import 'domain/entities/tor_proxy_endpoint.dart';
import 'domain/entities/tor_session.dart';
import 'domain/entities/tor_transport.dart';
import 'domain/usecases/close_tor_usecase.dart';
import 'domain/usecases/ensure_tor_ready_usecase.dart';
import 'domain/usecases/get_tor_connection_usecase.dart';
import 'domain/usecases/get_tor_transport_mode_usecase.dart';
import 'domain/usecases/open_tor_session_usecase.dart';
import 'domain/usecases/retry_tor_connection_usecase.dart';
import 'domain/usecases/set_tor_transport_mode_usecase.dart';
import 'domain/usecases/verify_external_tor_usecase.dart';
import 'domain/usecases/watch_tor_connection_usecase.dart';

/// Public Tor facade. Policy lives here in Dart; native packages expose only
/// the Arti and IPtProxy primitives used by its internal adapters.
class Tor {
  final EmbeddedTor embedded;
  final ExternalTor external;
  final CloseTorUsecase _close;

  const Tor(this.embedded, this.external, this._close);

  Future<void> dispose() => _close.execute();
}

class EmbeddedTor {
  final GetTorConnectionUsecase _getConnection;
  final GetTorTransportModeUsecase _getMode;
  final EnsureTorReadyUsecase _ensureReady;
  final RetryTorConnectionUsecase _retry;
  final WatchTorConnectionUsecase _watch;
  final SetTorTransportModeUsecase _setMode;
  final TorSessions sessions;

  const EmbeddedTor(
    this._getConnection,
    this._getMode,
    this._ensureReady,
    this._retry,
    this._watch,
    this._setMode,
    this.sessions,
  );

  TorConnectionState get current => _getConnection.execute();

  TorTransportMode get mode => _getMode.execute();

  Stream<TorConnectionState> get states => _watch.execute();

  Future<TorConnectionState> ensureReady() => _ensureReady.execute();

  Future<TorConnectionState> retry() => _retry.execute();

  Future<TorConnectionState> setMode(TorTransportMode mode) =>
      _setMode.execute(mode);
}

class TorSessions {
  final OpenTorSessionUsecase _open;

  const TorSessions(this._open);

  Future<TorSession> open() => _open.execute();
}

class ExternalTor {
  final VerifyExternalTorUsecase _verify;

  const ExternalTor(this._verify);

  Future<TorConnectionState> verify(TorProxyEndpoint endpoint) =>
      _verify.execute(endpoint);
}
