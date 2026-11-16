import 'dart:async';

import '../domain/entities/tor_connection_state.dart';
import '../domain/entities/tor_proxy_endpoint.dart';
import '../domain/entities/tor_route.dart';
import '../domain/entities/tor_session.dart';
import '../domain/entities/tor_transport.dart';
import '../domain/ports/embedded_tor_port.dart';
import '../domain/ports/network_presence_port.dart';
import '../domain/tor_failure.dart';
import '../domain/tor_repository.dart';

/// A direct bootstrap that has not finished in this time will not.
const defaultDirectBudget = Duration(minutes: 2);

/// Snowflake reaches Tor through volunteer proxies and can take minutes on a
/// filtered network. The slowest success measured on a relay-blocking Wi-Fi
/// took 499 s, rounded up here.
const defaultSnowflakeBudget = Duration(minutes: 10);

/// On an open network a direct bootstrap gains progress within a second or
/// two. On a Wi-Fi blocking relays it sat at 0% for 61 s before Arti said
/// "offline", or at 85% without ever carrying traffic: no progress for this
/// long hands a direct attempt that has a fallback over to Snowflake.
const defaultStallFallbackAfter = Duration(seconds: 20);

/// Marks a direct attempt ended by a persistent censorship verdict.
final _censoredOutcome = Object();

/// Marks an attempt that outlived its budget.
final _expiredOutcome = Object();

final class TorRepositoryImpl implements TorRepository {
  final EmbeddedTorPort _embeddedTor;
  final Future<void> Function(TorTransport)? _onSuccessfulTransport;
  final NetworkPresencePort? _network;

  /// How long a censorship verdict must hold before automatic mode stops the
  /// direct attempt and switches to Snowflake.
  final Duration _censorshipFallbackAfter;

  /// How long a direct attempt with a fallback may go without new progress.
  final Duration _stallFallbackAfter;
  final Duration _directBudget;
  final Duration _snowflakeBudget;
  final DateTime Function() _now;
  final StreamController<TorConnectionState> _changes =
      StreamController<TorConnectionState>.broadcast(sync: true);

  TorConnectionState _current = const TorUninitialized();
  TorTransportMode _mode;
  TorTransport? _lastSuccessfulTransport;
  StreamSubscription<EmbeddedTorEvent>? _embeddedSubscription;

  /// The start every concurrent caller joins, so one screen opening does not
  /// tear down the bootstrap another one is already waiting on.
  Future<TorConnectionState>? _inFlight;
  bool _retryInFlight = false;

  /// The user asked for Snowflake from a failure screen; cleared by a mode change.
  bool _snowflakeRequested = false;

  /// Bumped by every start. A connection whose generation is stale must stay
  /// silent: a newer one owns the published state.
  int _generation = 0;
  bool _closed = false;

  factory TorRepositoryImpl(
    EmbeddedTorPort embeddedTor, {
    TorTransportMode initialMode = TorTransportMode.automatic,
    TorTransport? lastSuccessfulTransport,
    Future<void> Function(TorTransport)? onSuccessfulTransport,
    NetworkPresencePort? network,
    Duration censorshipFallbackAfter = const Duration(seconds: 15),
    Duration stallFallbackAfter = defaultStallFallbackAfter,
    Duration directBudget = defaultDirectBudget,
    Duration snowflakeBudget = defaultSnowflakeBudget,
    DateTime Function()? now,
  }) => TorRepositoryImpl._(
    embeddedTor,
    initialMode,
    lastSuccessfulTransport,
    onSuccessfulTransport,
    network,
    censorshipFallbackAfter,
    stallFallbackAfter,
    directBudget,
    snowflakeBudget,
    now ?? DateTime.now,
  );

  TorRepositoryImpl._(
    this._embeddedTor,
    this._mode,
    this._lastSuccessfulTransport,
    this._onSuccessfulTransport,
    this._network,
    this._censorshipFallbackAfter,
    this._stallFallbackAfter,
    this._directBudget,
    this._snowflakeBudget,
    this._now,
  );

  @override
  TorConnectionState get current => _current;

  @override
  TorTransportMode get mode => _mode;

  @override
  Stream<TorConnectionState> watch() => Stream<TorConnectionState>.multi((
    sink,
  ) {
    final subscription = _changes.stream.listen(
      sink.add,
      onError: sink.addError,
      onDone: sink.close,
    );
    // Subscribe first, then snapshot: an update between these operations is
    // either forwarded or reflected here, never lost like a broadcast-only API.
    sink.add(_current);
    sink.onCancel = subscription.cancel;
  });

  @override
  Future<TorConnectionState> ensureReady() async {
    // A cached "ready" is not enough: the process may have been backgrounded
    // long enough for the SOCKS listener to die under us.
    final ready = _current;
    if (ready is TorReady &&
        _accepts(ready.route.transport) &&
        await _embeddedTor.isAlive()) {
      return ready;
    }

    return _inFlight ?? _begin(retry: false);
  }

  @override
  Future<TorConnectionState> retry({bool snowflake = false}) {
    final inFlight = _inFlight;
    if (snowflake && !_snowflakeRequested) {
      _snowflakeRequested = true;
      // A retry already running on the direct path must not absorb this one.
      return _begin(retry: true);
    }
    if (inFlight != null && _retryInFlight) return inFlight;

    return _begin(retry: true);
  }

  @override
  Future<TorConnectionState> setMode(TorTransportMode mode) {
    if (_mode == mode) return ensureReady();
    _mode = mode;
    _snowflakeRequested = false;
    return retry();
  }

  @override
  Future<TorSession> openSession() async {
    while (!_closed) {
      final state = await ensureReady();
      if (!identical(state, _current)) continue;

      if (state is TorReady && _accepts(state.route.transport)) {
        final generation = _generation;
        try {
          final session = await _embeddedTor.openSession();
          if (_isCurrent(generation) &&
              _current is TorReady &&
              _accepts(session.transport)) {
            return session;
          }
          await session.close();
        } on TorBackendException {
          if (_isCurrent(generation)) rethrow;
        }
        continue;
      }
      if (state case TorUnavailable(:final failure)) {
        throw TorBackendException(failure);
      }
      throw const TorBackendException(
        TorUnexpectedFailure('Embedded Tor did not become ready'),
      );
    }
    throw const TorBackendException(
      TorUnexpectedFailure('Embedded Tor repository is closed'),
    );
  }

  @override
  Future<void> setDormant(bool dormant) => _embeddedTor.setDormant(dormant);

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _generation++;
    await _embeddedSubscription?.cancel();
    await _embeddedTor.close();
    await _changes.close();
  }

  Future<TorConnectionState> _begin({required bool retry}) {
    final operation = _connect(++_generation, retry: retry);
    _inFlight = operation;
    _retryInFlight = retry;

    operation.whenComplete(() {
      if (identical(_inFlight, operation)) {
        _inFlight = null;
        _retryInFlight = false;
      }
    });
    return operation;
  }

  Future<TorConnectionState> _connect(
    int generation, {
    required bool retry,
  }) async {
    await _embeddedSubscription?.cancel();
    _embeddedSubscription = null;

    // Stop before starting, but only when retrying: a retry has to invalidate a
    // client whose bootstrap has not returned yet, instead of queueing behind
    // it. `ensureReady()` must not, because arti's readiness is not monotonic —
    // a background directory refresh reports Connecting again over a live SOCKS
    // route, and tearing that down turns a hiccup into a full re-bootstrap.
    // Skipping the stop is what makes the backend's adopt-existing path
    // reachable, which also spares watchers a spurious Stopped transition.
    if (retry) {
      await _embeddedTor.stop();
      if (!_isCurrent(generation)) return _current;
    }

    // Censorship watch for the attempt in flight: a verdict that holds for
    // [_censorshipFallbackAfter] ends a direct attempt that has a fallback.
    var circumvention = false;
    DateTime? deadline;
    Completer<void>? censored;
    Timer? censorshipTimer;
    // Stall watch: Arti's progress is not monotonic, so only a new best counts.
    var best = -1.0;
    Timer? stallTimer;
    void watchProgress(double progress) {
      final pending = censored;
      if (pending == null || pending.isCompleted) return;
      if (progress <= best && stallTimer != null) return;
      best = progress > best ? progress : best;
      stallTimer?.cancel();
      stallTimer = Timer(_stallFallbackAfter, () {
        if (!pending.isCompleted) pending.complete();
      });
    }

    void watchCensorship(TorDiagnostic? diagnostic) {
      final pending = censored;
      if (pending == null || pending.isCompleted) return;
      if (diagnostic?.worthSnowflake ?? false) {
        censorshipTimer ??= Timer(_censorshipFallbackAfter, () {
          if (!pending.isCompleted) pending.complete();
        });
      } else {
        censorshipTimer?.cancel();
        censorshipTimer = null;
      }
    }

    _embeddedSubscription = _embeddedTor.watch().listen((event) {
      if (!_isCurrent(generation)) return;
      switch (event) {
        case EmbeddedTorConnecting(
          :final progress,
          :final diagnostic,
          :final transport,
        ):
          final classified = _classify(diagnostic);
          watchCensorship(classified);
          watchProgress(progress);
          _emit(
            TorConnecting(
              source: TorSource.embedded,
              progress: progress,
              diagnostic: classified,
              transport: transport,
              circumvention: circumvention,
              deadline: deadline,
            ),
          );
        case EmbeddedTorReady(:final endpoint, :final transport):
          _emit(_readyOn(endpoint, transport));
        case EmbeddedTorStopped():
          _emit(const TorStopped(TorSource.embedded));
        case EmbeddedTorFailed(:final failure):
          _emit(TorUnavailable(source: TorSource.embedded, failure: failure));
      }
    });

    final attempts = _attempts();
    for (var index = 0; index < attempts.length; index++) {
      final transport = attempts[index];
      final hasFallback = index + 1 < attempts.length;
      censorshipTimer?.cancel();
      censorshipTimer = null;
      final pendingCensorship = hasFallback ? Completer<void>() : null;
      censored = pendingCensorship;
      // Armed before the first event: a bootstrap that never reports is a stall too.
      stallTimer?.cancel();
      stallTimer = null;
      best = -1;
      watchProgress(0);
      final budget = transport == TorTransport.snowflake
          ? _snowflakeBudget
          : _directBudget;
      deadline = _now().add(budget);
      final expired = Completer<void>();
      final budgetTimer = Timer(budget, () {
        if (!expired.isCompleted) expired.complete();
      });
      _emit(
        TorConnecting(
          source: TorSource.embedded,
          transport: transport,
          circumvention: circumvention,
          deadline: deadline,
        ),
      );
      try {
        final start = _embeddedTor.start(transport);
        final Object? outcome = await Future.any<Object?>([
          start,
          expired.future.then((_) => _expiredOutcome),
          if (pendingCensorship != null)
            pendingCensorship.future.then((_) => _censoredOutcome),
        ]);
        if (!_isCurrent(generation)) return _current;
        if (identical(outcome, _censoredOutcome) ||
            identical(outcome, _expiredOutcome)) {
          // The interrupted start fails with a cancellation nobody awaits.
          unawaited(start.then((_) {}, onError: (_) {}));
          await _embeddedTor.stop();
          if (!_isCurrent(generation)) return _current;
          if (identical(outcome, _expiredOutcome) && !hasFallback) {
            return _fail(
              generation,
              TorBootstrapTimeoutFailure(
                '${transport.name} not ready within ${budget.inSeconds}s',
              ),
            );
          }
          circumvention = true;
          continue;
        }
        final endpoint = outcome! as TorProxyEndpoint;

        _lastSuccessfulTransport = transport;
        unawaited(_onSuccessfulTransport?.call(transport));
        final ready = _readyOn(endpoint, transport);
        _emit(ready);
        return ready;
      } on TorBackendException catch (error) {
        if (hasFallback && _shouldUseSnowflake(error.failure)) {
          circumvention = true;
          continue;
        }
        return _fail(generation, error.failure);
      } catch (error) {
        return _fail(generation, TorUnexpectedFailure(error.toString()));
      } finally {
        budgetTimer.cancel();
        censorshipTimer?.cancel();
        censorshipTimer = null;
        stallTimer?.cancel();
        stallTimer = null;
      }
    }
    return _fail(
      generation,
      const TorUnexpectedFailure('No embedded Tor transport was attempted'),
    );
  }

  /// Arti says "offline" when no relay answers. With a device network that
  /// means relays are unreachable, which is how a network blocks Tor.
  TorDiagnostic? _classify(TorDiagnostic? diagnostic) =>
      diagnostic == TorDiagnostic.offline && (_network?.hasNetwork ?? false)
      ? TorDiagnostic.noInternetOrBlocked
      : diagnostic;

  TorReady _readyOn(TorProxyEndpoint endpoint, TorTransport transport) =>
      TorReady(
        TorRoute(
          source: TorSource.embedded,
          endpoint: endpoint,
          evidence: TorReadinessEvidence.embeddedBootstrap,
          transport: transport,
        ),
      );

  List<TorTransport> _attempts() => switch (_mode) {
    TorTransportMode.direct => const [TorTransport.direct],
    TorTransportMode.snowflake => const [TorTransport.snowflake],
    TorTransportMode.automatic
        when _snowflakeRequested ||
            _lastSuccessfulTransport == TorTransport.snowflake =>
      const [TorTransport.snowflake],
    TorTransportMode.automatic => const [
      TorTransport.direct,
      TorTransport.snowflake,
    ],
  };

  bool _accepts(TorTransport? transport) => switch (_mode) {
    TorTransportMode.automatic => transport != null,
    TorTransportMode.direct => transport == TorTransport.direct,
    TorTransportMode.snowflake => transport == TorTransport.snowflake,
  };

  bool _shouldUseSnowflake(TorFailure failure) => switch (failure) {
    TorBootstrapTimeoutFailure() => true,
    TorBootstrapFailure(:final diagnostic) =>
      _classify(diagnostic)?.worthSnowflake ?? false,
    _ => false,
  };

  TorConnectionState _fail(int generation, TorFailure failure) {
    if (!_isCurrent(generation)) return _current;

    final unavailable = TorUnavailable(
      source: TorSource.embedded,
      failure: failure,
    );
    _emit(unavailable);
    return unavailable;
  }

  bool _isCurrent(int generation) => !_closed && generation == _generation;

  void _emit(TorConnectionState state) {
    if (_closed) return;
    _current = state;
    _changes.add(state);
  }
}
