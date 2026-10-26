import 'dart:async';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_tor/tor.dart' as tor;
import 'package:primitives/primitives.dart';
import '../entities/recoverbull_connection.dart';
import '../recoverbull_failure.dart';
import '../recoverbull_flow_failure.dart';
import '../recoverbull_tor_route.dart';
import '../recoverbull_route_port.dart';
import 'connect_to_key_server_usecase.dart';
import 'ensure_recoverbull_tor_session_usecase.dart';

/// Owns a flow's route and serializes user-requested connection attempts.
final class ManageRecoverBullConnectionUsecase implements RecoverBullRoutePort {
  final LogSink log;
  final ConnectToKeyServerUsecase _connectToKeyServerUsecase;
  final EnsureRecoverBullTorSessionUsecase _ensureRecoverBullTorSessionUsecase;
  final tor.WatchTorConnectionUsecase _watchTorConnectionUsecase;
  final _updates = StreamController<RecoverBullConnection>.broadcast(
    sync: true,
  );
  final Map<RecoverBullTorRoute, int> _borrowers = {};
  final Set<RecoverBullTorRoute> _retired = {};
  RecoverBullConnection state = const RecoverBullConnection();
  StreamSubscription<tor.TorConnectionState>? _torSubscription;
  Future<void> _torUpdates = Future.value();
  Future<Result<RecoverBullTorRoute, RecoverBullFailure>>?
  _pendingRoutePreparation;
  tor.TorSource? _pendingRouteFailureSource;
  RecoverBullTorRoute? _route;
  int _routeGeneration = 0;
  bool _closed = false;
  bool _initializing = false;
  bool _connectionRequested = false;
  bool _serverCheckInFlight = false;
  bool _serverCheckRequested = false;
  bool _newRouteRequired = false;

  ManageRecoverBullConnectionUsecase({
    required this.log,
    required this._connectToKeyServerUsecase,
    required this._ensureRecoverBullTorSessionUsecase,
    required this._watchTorConnectionUsecase,
  }) {
    _torSubscription = _watchTorConnectionUsecase.execute().listen((next) {
      _torUpdates = _torUpdates.then((_) async {
        if (!_closed) await _onTorConnectionChanged(next);
      });
    });
  }

  Stream<RecoverBullConnection> get updates => _updates.stream;
  RecoverBullTorRoute? get route => _route;

  Future<void> execute({
    bool initialize = false,
    bool restart = false,
    bool newCircuit = false,
  }) async {
    if (_closed) return;
    _connectionRequested = true;
    if (newCircuit) {
      if (_initializing || _pendingRoutePreparation != null) return;
      if (_source(state.torConnection) != tor.TorSource.embedded) return;
      log.fine(
        'recoverbull.route.new after_failures=${state.keyServerFailures}',
      );
      _newRouteRequired = true;
      initialize = true;
    }
    if (initialize || _route == null) {
      if (_initializing) return;
      _initializing = true;
      try {
        await _onTorInitialization(restart);
      } finally {
        _initializing = false;
        _drainServerCheck();
      }
    } else if (!_serverCheckInFlight) {
      await _onServerCheck();
    }
  }

  /// A retiring route stays open until its last fetch/store returns.
  @override
  Future<T> borrowRoute<T>(
    Future<T> Function(RecoverBullTorRoute?) operation,
  ) async {
    final route = _route;
    if (route == null) return operation(null);
    _borrowers[route] = (_borrowers[route] ?? 0) + 1;
    try {
      return await operation(route);
    } finally {
      final remaining = (_borrowers[route] ?? 1) - 1;
      if (remaining > 0) {
        _borrowers[route] = remaining;
      } else {
        _borrowers.remove(route);
        if (_retired.remove(route)) await route.closeQuietly();
      }
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _routeGeneration++;
    await _torSubscription?.cancel();
    final pending = _pendingRoutePreparation;
    if (pending != null) {
      if (await pending case Ok(:final value)) await _retireRoute(value);
    }
    final retained = _route;
    if (retained != null) await _retireRoute(retained);
    await _updates.close();
  }

  void _emit(RecoverBullConnection next) {
    if (_closed) return;
    state = next;
    _updates.add(next);
  }

  Future<void> _retireRoute(RecoverBullTorRoute route) async {
    if (identical(_route, route)) _route = null;
    if ((_borrowers[route] ?? 0) > 0) {
      _retired.add(route);
    } else {
      await route.closeQuietly();
    }
  }

  void _requestServerCheck() {
    _serverCheckRequested = true;
    _drainServerCheck();
  }

  void _drainServerCheck() {
    if (_closed ||
        _initializing ||
        _serverCheckInFlight ||
        !_connectionRequested ||
        !_serverCheckRequested ||
        _route == null) {
      return;
    }
    _serverCheckRequested = false;
    unawaited(_onServerCheck());
  }

  tor.TorSource? _source(tor.TorConnectionState value) => switch (value) {
    tor.TorReady(:final route) => route.source,
    tor.TorConnecting(:final source) ||
    tor.TorUnavailable(:final source) => source,
    _ => null,
  };

  Future<void> _onTorConnectionChanged(tor.TorConnectionState next) async {
    if (_source(state.torConnection) == tor.TorSource.external &&
        _source(next) != tor.TorSource.external) {
      return;
    }
    // A directory refresh does not invalidate a usable flow route.
    if (state.torConnection is tor.TorReady &&
        next is tor.TorConnecting &&
        next.diagnostic == null) {
      log.info('recoverbull.tor.directory_refresh');
      return;
    }
    if (next case tor.TorUnavailable(
      :final source,
    ) when _pendingRoutePreparation != null) {
      _pendingRouteFailureSource = source;
    }
    final retained = _route;
    if (retained != null &&
        (next is tor.TorStopped ||
            next is tor.TorUninitialized ||
            next is tor.TorUnavailable)) {
      _newRouteRequired = true;
      await _retireRoute(retained);
      if (_closed) return;
    }
    // Readiness cannot overwrite a vault failure or start an idle flow.
    _emit(state.copyWith(torConnection: next));
    if (next is tor.TorReady &&
        _connectionRequested &&
        state.keyServerStatus == KeyServerStatus.unknown &&
        _pendingRoutePreparation == null &&
        !_initializing) {
      if (_route == null) {
        unawaited(execute(initialize: true));
      } else {
        _requestServerCheck();
      }
    }
  }

  Future<void> _onTorInitialization(bool restart) async {
    final retained = _route;
    if (!restart && !_newRouteRequired && retained != null) {
      _emit(
        state.copyWith(
          failure: null,
          keyServerStatus: KeyServerStatus.unknown,
          torConnection: tor.TorReady(retained.route),
        ),
      );
      log.fine('recoverbull.tor.initialization.reused_route');
      _requestServerCheck();
      return;
    }
    final generation = ++_routeGeneration;
    _emit(
      state.copyWith(
        failure: null,
        keyServerStatus: KeyServerStatus.unknown,
        keyServerFailures: 0,
      ),
    );
    if (retained != null) await _retireRoute(retained);
    var restartEmbedded = restart;
    while (!_closed && generation == _routeGeneration) {
      _pendingRouteFailureSource = null;
      final newRoute = _newRouteRequired;
      _newRouteRequired = false;
      final preparation = newRoute
          ? _ensureRecoverBullTorSessionUsecase.execute(
              restartEmbedded: restartEmbedded,
              newRoute: true,
            )
          : _ensureRecoverBullTorSessionUsecase.execute(
              restartEmbedded: restartEmbedded,
            );
      restartEmbedded = false;
      _pendingRoutePreparation = preparation;
      final bootstrap = Stopwatch()..start();
      final result = await preparation;
      log.fine(
        'recoverbull.timing phase=tor_bootstrap duration_ms=${bootstrap.elapsedMilliseconds} outcome=${result is Ok ? 'success' : 'failure'}',
      );
      final failedSource = _pendingRouteFailureSource;
      _pendingRouteFailureSource = null;
      if (identical(_pendingRoutePreparation, preparation)) {
        _pendingRoutePreparation = null;
      }
      if (_closed || generation != _routeGeneration) {
        if (result case Ok(:final value)) await _retireRoute(value);
        return;
      }
      if (result case Ok(:final value) when value.source == failedSource) {
        await _retireRoute(value);
        _newRouteRequired = true;
        if (state.torConnection is tor.TorReady) continue;
        return;
      }
      switch (result) {
        case Ok(:final value):
          _route = value;
          _emit(
            state.copyWith(
              torConnection: tor.TorReady(value.route),
              keyServerFailures: 0,
            ),
          );
          _requestServerCheck();
        case Err(:final failure):
          final external = failure is ExternalTorProxyUnavailableFailure;
          _emit(
            state.copyWith(
              torConnection: tor.TorUnavailable(
                source: external
                    ? tor.TorSource.external
                    : tor.TorSource.embedded,
                failure: external
                    ? tor.TorExternalProxyUnavailableFailure(failure.logMessage)
                    : tor.TorBootstrapFailure(failure.logMessage),
              ),
              failure: torConnectionFailure(failure),
              keyServerStatus: KeyServerStatus.offline,
            ),
          );
      }
      return;
    }
  }

  Future<void> _onServerCheck() async {
    final route = _route;
    if (route == null || _closed) return;
    _serverCheckInFlight = true;
    _serverCheckRequested = false;
    final generation = _routeGeneration;
    // Preserve the reason and its technical detail while Retry is running.
    _emit(
      state.copyWith(
        keyServerStatus: KeyServerStatus.connecting,
        keyServerAttempt: 1,
        keyServerAttempts: 1,
      ),
    );
    try {
      final result = await borrowRoute(
        (retained) => _connectToKeyServerUsecase.execute(route: retained),
      );
      if (_closed || generation != _routeGeneration) return;
      switch (result) {
        case Err(:final failure):
          if (failure case KeyServerUnavailableFailure(
            cause: KeyServerUnreachableCause.proxyGone,
          )) {
            _newRouteRequired = true;
            await _retireRoute(route);
            if (_closed) return;
          }
          _emit(
            state.copyWith(
              failure: serverCheckFailure(failure),
              keyServerStatus: KeyServerStatus.offline,
              keyServerFailures: state.keyServerFailures + 1,
            ),
          );
        case Ok(value: false):
          _emit(
            state.copyWith(
              failure: const KeyServerConnectionFailure(),
              keyServerStatus: KeyServerStatus.offline,
              keyServerFailures: state.keyServerFailures + 1,
            ),
          );
        case Ok(value: true):
          _emit(
            state.copyWith(
              failure: null,
              keyServerStatus: KeyServerStatus.online,
            ),
          );
      }
    } on Exception catch (error) {
      if (_closed || generation != _routeGeneration) return;
      log.warning(
        'recoverbull.server_check.unexpected type=${error.runtimeType}',
      );
      _newRouteRequired = true;
      await _retireRoute(route);
      _emit(
        state.copyWith(
          failure: const RecoverBullUnexpectedFailure(),
          keyServerStatus: KeyServerStatus.offline,
        ),
      );
    } finally {
      _serverCheckInFlight = false;
      if (generation != _routeGeneration && !_closed && _route != null) {
        _serverCheckRequested = true;
      }
      _drainServerCheck();
    }
  }
}
