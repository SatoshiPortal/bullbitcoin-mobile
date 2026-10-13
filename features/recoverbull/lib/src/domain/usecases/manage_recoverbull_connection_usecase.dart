import 'dart:async';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_tor/tor.dart' as tor;
import 'package:primitives/primitives.dart';
import '../recoverbull_failure.dart' as core;
import '../recoverbull_failure.dart';
import '../recoverbull_flow_failure.dart';
import '../recoverbull_tor_route.dart';
import '../entities/recoverbull_connection.dart';
import 'connect_to_key_server_usecase.dart';
import 'ensure_recoverbull_tor_session_usecase.dart';

/// Owns one flow's isolated route, readiness grace, and serialized retries.
final class ManageRecoverBullConnectionUsecase {
  final LogSink log;
  final _updates = StreamController<RecoverBullConnection>.broadcast(
    sync: true,
  );
  RecoverBullConnection state = const RecoverBullConnection();
  bool _initializing = false;
  final ConnectToKeyServerUsecase _connectToKeyServerUsecase;
  final EnsureRecoverBullTorSessionUsecase _ensureRecoverBullTorSessionUsecase;
  final tor.WatchTorConnectionUsecase _watchTorConnectionUsecase;
  final DateTime Function() _now;
  final Timer Function(Duration, void Function()) _scheduleTimer;

  StreamSubscription<tor.TorConnectionState>? _torSubscription;
  Future<Result<RecoverBullTorRoute, core.RecoverBullFailure>>?
  _pendingRoutePreparation;
  bool _closed = false;
  RecoverBullTorRoute? _route;
  int _routeGeneration = 0;
  bool _serverCheckInFlight = false;
  bool _serverCheckRequested = false;
  Timer? _torReadinessGraceTimer;
  tor.TorConnecting? _pendingTorConnecting;
  DateTime? _torReadinessLostAt;
  int _torReadinessGraceToken = 0;

  void _requestServerCheck() {
    _serverCheckRequested = true;
    if (!_serverCheckInFlight && !_closed) {
      _serverCheckRequested = false;
      unawaited(_onServerCheck());
    }
  }

  ManageRecoverBullConnectionUsecase({
    required this.log,
    required this._connectToKeyServerUsecase,
    required this._ensureRecoverBullTorSessionUsecase,
    required this._watchTorConnectionUsecase,
    DateTime Function()? now,
    Timer Function(Duration, void Function())? scheduleTimer,
  }) : _now = now ?? DateTime.now,
       _scheduleTimer = scheduleTimer ?? Timer.new {
    _torSubscription = _watchTorConnectionUsecase.execute().listen((next) {
      if (!_closed) unawaited(_onTorConnectionChanged(next));
    });
  }

  Stream<RecoverBullConnection> get updates => _updates.stream;
  RecoverBullTorRoute? get route => _route;

  Future<void> execute({bool initialize = false, bool restart = false}) async {
    if (_closed) return;
    if (initialize) {
      if (_initializing) return;
      _initializing = true;
      try {
        await _onTorInitialization(restart);
      } finally {
        _initializing = false;
      }
    } else if (!_serverCheckInFlight) {
      await _onServerCheck();
    }
  }

  void _emit(RecoverBullConnection next) {
    if (_closed) return;
    state = next;
    _updates.add(next);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _cancelTorReadinessGrace();
    await _torSubscription?.cancel();
    final pending = _pendingRoutePreparation;
    if (pending != null) {
      if (await pending case Ok(:final value)) await value.closeQuietly();
    }
    await _route?.closeQuietly();
    _route = null;
    await _updates.close();
  }

  Future<void> _onTorConnectionChanged(tor.TorConnectionState next) async {
    final nextIsExternal = switch (next) {
      tor.TorReady(:final route) => route.source == tor.TorSource.external,
      tor.TorConnecting(:final source) => source == tor.TorSource.external,
      tor.TorUnavailable(:final source) => source == tor.TorSource.external,
      tor.TorUninitialized() || tor.TorStopped() => false,
    };
    if (state.torConnection case tor.TorReady(
      :final route,
    ) when route.source == tor.TorSource.external && !nextIsExternal) {
      return;
    }
    if (state.torConnection case tor.TorConnecting(
      :final source,
    ) when source == tor.TorSource.external && !nextIsExternal) {
      return;
    }
    if (state.torConnection case tor.TorUnavailable(
      :final source,
    ) when source == tor.TorSource.external && !nextIsExternal) {
      return;
    }
    if (state.torConnection is tor.TorReady &&
        next is tor.TorConnecting &&
        next.diagnostic == null) {
      _pendingTorConnecting = next;
      _torReadinessLostAt ??= _now();
      log.fine('recoverbull.tor.directory_refresh');
      _scheduleTorReadinessGrace();
      return;
    }
    _cancelTorReadinessGrace();
    _emit(state.copyWith(torConnection: next));

    // An external proxy has no embedded lifecycle to restart. Let the real
    // server check observe whether the retained external route is still usable;
    // never manufacture recovery from an embedded readiness event.
    if (next is tor.TorUnavailable && nextIsExternal && _route != null) {
      _requestServerCheck();
    }

    // The global readiness stream can emit before the flow's initialization
    // event. It proves embedded Tor is ready, but it does not own the isolated
    // route that this flow must reuse. Wait for `_onTorInitialization` to
    // acquire that route instead of starting a competing server check with a
    // second short-lived route.
    if (next is tor.TorReady &&
        state.keyServerStatus == KeyServerStatus.unknown &&
        _route != null) {
      _requestServerCheck();
    }
  }

  void _scheduleTorReadinessGrace() {
    if (_torReadinessGraceTimer != null) return;
    // Five seconds covers the observed 0.9-second and 173-millisecond dips
    // while still revealing a readiness loss when Arti stops emitting.
    final lostAt = _torReadinessLostAt!;
    final remaining = const Duration(seconds: 5) - _now().difference(lostAt);
    _torReadinessGraceTimer = _scheduleTimer(
      remaining.isNegative ? Duration.zero : remaining,
      () => _onTorReadinessGraceExpired(_torReadinessGraceToken),
    );
  }

  Future<void> _onTorReadinessGraceExpired(int token) async {
    if (token != _torReadinessGraceToken) return;
    _torReadinessGraceTimer = null;
    final lostAt = _torReadinessLostAt;
    if (lostAt == null || _pendingTorConnecting == null) return;
    final remaining = const Duration(seconds: 5) - _now().difference(lostAt);
    if (remaining > Duration.zero) {
      _scheduleTorReadinessGrace();
      return;
    }
    final next = _pendingTorConnecting!;
    _pendingTorConnecting = null;
    _torReadinessLostAt = null;
    log.warning('recoverbull.tor.readiness_lost');
    _emit(state.copyWith(torConnection: next));
  }

  void _cancelTorReadinessGrace() {
    _torReadinessGraceToken++;
    _torReadinessGraceTimer?.cancel();
    _torReadinessGraceTimer = null;
    _pendingTorConnecting = null;
    _torReadinessLostAt = null;
  }

  Future<void> _onTorInitialization(bool restart) async {
    final generation = ++_routeGeneration;
    _emit(
      state.copyWith(failure: null, keyServerStatus: KeyServerStatus.unknown),
    );
    if (!restart && _route != null) {
      log.fine('recoverbull.tor.initialization.reused_route');
      _emit(state.copyWith(torConnection: tor.TorReady(_route!.route)));
      _requestServerCheck();
      return;
    }
    final oldRoute = _route;
    _route = null;
    if (oldRoute != null) {
      try {
        await oldRoute.close();
      } on Exception catch (error) {
        log.warning(
          'recoverbull.tor.route.close.failed error_type=${error.runtimeType}',
        );
      }
    }
    if (_closed) return;
    final preparation = _ensureRecoverBullTorSessionUsecase.execute(
      restartEmbedded: restart,
    );
    _pendingRoutePreparation = preparation;
    final bootstrapTimer = Stopwatch()..start();
    final result = await preparation;
    bootstrapTimer.stop();
    log.fine(
      'recoverbull.timing phase=tor_bootstrap '
      'duration_ms=${bootstrapTimer.elapsedMilliseconds} '
      'outcome=${result is Ok ? 'success' : 'failure'}',
    );
    if (identical(_pendingRoutePreparation, preparation)) {
      _pendingRoutePreparation = null;
    }
    if (_closed || generation != _routeGeneration) {
      if (result case Ok(:final value)) await value.closeQuietly();
      return;
    }
    switch (result) {
      case Ok(:final value):
        _route = value;
        final connection = tor.TorReady(value.route);
        if (_closed || generation != _routeGeneration) {
          await value.closeQuietly();
          return;
        }
        _emit(state.copyWith(torConnection: connection));
        _requestServerCheck();
      case Err(:final failure):
        final torFailure = failure is core.ExternalTorProxyUnavailableFailure
            ? tor.TorExternalProxyUnavailableFailure(failure.logMessage)
            : tor.TorBootstrapFailure(failure.logMessage);
        _emit(
          state.copyWith(
            torConnection: tor.TorUnavailable(
              source: failure is core.ExternalTorProxyUnavailableFailure
                  ? tor.TorSource.external
                  : tor.TorSource.embedded,
              failure: torFailure,
            ),
            failure: torConnectionFailure(failure),
            keyServerStatus: KeyServerStatus.offline,
          ),
        );
    }
  }

  Future<void> _onServerCheck() async {
    _serverCheckInFlight = true;
    _serverCheckRequested = false;
    final generation = _routeGeneration;
    final route = _route;
    final checkTimer = Stopwatch()..start();
    try {
      // `torStatus` is not emitted here: it is driven by the subscription set
      // up in the constructor. Emitting a snapshot at this point is what made a
      // healthy cold start look like a Tor failure.
      const retries = ConnectToKeyServerUsecase.maxAttempts;
      var attemptsPerformed = 0;
      if (generation != _routeGeneration) {
        _logAbandonedServerCheck('generation_changed');
        return;
      }
      _emit(
        state.copyWith(
          failure: null,
          keyServerStatus: KeyServerStatus.connecting,
          keyServerAttempt: 0,
          keyServerAttempts: retries,
        ),
      );

      final result = await _connectToKeyServerUsecase.execute(
        route: route,
        // Published before the call, so the screen shows which attempt is
        // actually in flight rather than which one already failed. Guarded:
        // the backoff outlives the screen when the user navigates away.
        onAttempt: (attempt) {
          attemptsPerformed = attempt;
          if (_closed || generation != _routeGeneration) {
            return;
          }
          _emit(state.copyWith(keyServerAttempt: attempt));
        },
      );
      if (_closed || generation != _routeGeneration) {
        _logAbandonedServerCheck(_closed ? 'closed' : 'generation_changed');
        return;
      }

      switch (result) {
        case Err(:final failure):
          log.warning(
            'recoverbull.server_check.failed '
            'cause=${failure.supportCause ?? 'unknown'} '
            'attempts=$attemptsPerformed',
          );
          _emit(
            state.copyWith(
              failure: fetchVaultKeyFailure(failure),
              keyServerStatus: KeyServerStatus.offline,
            ),
          );
        case Ok(value: false):
          log.warning(
            'recoverbull.server_check.exhausted attempts=$attemptsPerformed',
          );
          _emit(
            state.copyWith(
              failure: const KeyServerConnectionFailure(),
              keyServerStatus: KeyServerStatus.offline,
            ),
          );
        case Ok(value: true):
          log.fine(
            'recoverbull.server_check.succeeded '
            'attempts=$attemptsPerformed',
          );
          // Tor's status is not forced here. It used to be set to `online` on
          // this path, which asserted Tor's health from the key server's reply;
          // the readiness stream is the only thing that knows, and the screen
          // latches it.
          _emit(state.copyWith(keyServerStatus: KeyServerStatus.online));
      }
    } on Exception catch (e) {
      if (_closed || generation != _routeGeneration) {
        _logAbandonedServerCheck(_closed ? 'closed' : 'generation_changed');
        return;
      }
      log.error(
        'recoverbull.server_check.unexpected error_type=${e.runtimeType}',
        trace: StackTrace.current,
      );
      _emit(
        state.copyWith(
          failure: const RecoverBullUnexpectedFailure(),
          keyServerStatus: KeyServerStatus.offline,
        ),
      );
    } finally {
      checkTimer.stop();
      log.fine(
        'recoverbull.timing phase=server_check '
        'duration_ms=${checkTimer.elapsedMilliseconds}',
      );
      _serverCheckInFlight = false;
      if (_serverCheckRequested && generation != _routeGeneration && !_closed) {
        _serverCheckRequested = false;
        unawaited(_onServerCheck());
      }
    }
  }

  void _logAbandonedServerCheck(String reason) {
    log.warning('recoverbull.server_check.abandoned reason=$reason');
  }
}
