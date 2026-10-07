import 'dart:async';

import '../domain/entities/tor_connection_state.dart';
import '../domain/entities/tor_proxy_endpoint.dart';
import '../domain/entities/tor_route.dart';
import '../domain/entities/tor_session.dart';
import '../domain/entities/tor_transport.dart';
import '../domain/ports/embedded_tor_port.dart';
import '../domain/tor_failure.dart';
import '../domain/tor_repository.dart';

/// How long an automatic-mode direct bootstrap may go without its progress
/// fraction increasing before Snowflake takes over, while it has not yet
/// reached a relay.
const _directStallLimit = Duration(seconds: 30);

/// The fraction from which arti has completed a handshake with a relay.
///
/// Arti weighs the bootstrap as 15% connection plus 85% directory, and the
/// connection share is only complete once a TLS handshake with a relay
/// succeeded (`arti-client` `BootstrapStatus::as_frac`, `tor-chanmgr`
/// `ConnStatus::frac`). Neither `TorStatus` nor its stage carries a structured
/// phase, and the stage is display text arti forbids parsing, so the fraction
/// is the only signal. It sits slightly below 0.15 to absorb the `f32`
/// rounding of arti's arithmetic.
///
/// A network that lets a relay handshake through is not blocking Tor, and
/// after that arti downloads its directory without reporting anything for 30
/// to 41 s on a healthy network — at 45% from a cold start, at 30% from a warm
/// cache (measured on a Pixel 5). So past this point silence is not a stall:
/// only the time limit and a censorship blockage still hand over to Snowflake.
///
/// A warm directory cache adds its own share without any connection, so a
/// censored start can pass this mark too; the censorship blockage arti
/// reports and the time limit still cover that case.
const _relayFraction = 0.14;

/// The most an automatic-mode direct bootstrap gets, progressing or not. It
/// matches arti's own bootstrap timeout, which this cuts short when it can.
const _directTimeLimit = Duration(seconds: 120);

final class TorRepositoryImpl implements TorRepository {
  final EmbeddedTorPort _embeddedTor;
  final Future<void> Function(TorTransport)? _onSuccessfulTransport;
  final Future<void> Function()? _onSessionInvalidated;
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

  /// Bumped by every start. A connection whose generation is stale must stay
  /// silent: a newer one owns the published state.
  int _generation = 0;
  bool _closed = false;

  factory TorRepositoryImpl(
    EmbeddedTorPort embeddedTor, {
    TorTransportMode initialMode = TorTransportMode.automatic,
    TorTransport? lastSuccessfulTransport,
    Future<void> Function(TorTransport)? onSuccessfulTransport,
    Future<void> Function()? onSessionInvalidated,
  }) => TorRepositoryImpl._(
    embeddedTor,
    initialMode,
    lastSuccessfulTransport,
    onSuccessfulTransport,
    onSessionInvalidated,
  );

  TorRepositoryImpl._(
    this._embeddedTor,
    this._mode,
    this._lastSuccessfulTransport,
    this._onSuccessfulTransport,
    this._onSessionInvalidated,
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

    if (ready is TorReady) unawaited(_onSessionInvalidated?.call());

    return _inFlight ?? _begin(retry: false);
  }

  @override
  Future<TorConnectionState> retry() {
    final inFlight = _inFlight;
    if (inFlight != null && _retryInFlight) return inFlight;

    unawaited(_onSessionInvalidated?.call());
    return _begin(retry: true);
  }

  @override
  Future<TorConnectionState> setMode(TorTransportMode mode) {
    if (_mode == mode) return ensureReady();
    _mode = mode;
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
    unawaited(_onSessionInvalidated?.call());
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

    // Until this connection settles, the start it awaits decides the outcome.
    // A backend stops between attempts and announces each start as stopped,
    // and a status stream torn down mid-bootstrap may fail: none of that ends
    // the sequence, and publishing it would fail every consumer waiting for
    // readiness while automatic mode hands over to Snowflake.
    var settled = false;
    _embeddedSubscription = _embeddedTor.watch().listen((event) {
      if (!_isCurrent(generation)) return;
      if (!settled &&
          (event is EmbeddedTorStopped || event is EmbeddedTorFailed)) {
        return;
      }
      switch (event) {
        case EmbeddedTorConnecting(
          :final progress,
          :final diagnostic,
          :final transport,
        ):
          _emit(
            TorConnecting(
              source: TorSource.embedded,
              progress: progress,
              diagnostic: diagnostic,
              transport: transport,
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

    try {
      final attempts = _attempts();
      for (var index = 0; index < attempts.length; index++) {
        final transport = attempts[index];
        final hasFallback = index + 1 < attempts.length;
        _emit(TorConnecting(source: TorSource.embedded, transport: transport));
        try {
          final endpoint = hasFallback
              ? await _startOrAbandon(transport)
              : await _embeddedTor.start(transport);
          if (!_isCurrent(generation)) return _current;

          _lastSuccessfulTransport = transport;
          unawaited(_onSuccessfulTransport?.call(transport));
          final ready = _readyOn(endpoint, transport);
          _emit(ready);
          return ready;
        } on _AbandonedAttempt {
          await _embeddedTor.stop();
          if (!_isCurrent(generation)) return _current;
          continue;
        } on TorBackendException catch (error) {
          if (hasFallback && _shouldUseSnowflake(error.failure)) continue;
          return _fail(generation, error.failure);
        } catch (error) {
          return _fail(generation, TorUnexpectedFailure(error.toString()));
        }
      }
      return _fail(
        generation,
        const TorUnexpectedFailure('No embedded Tor transport was attempted'),
      );
    } finally {
      settled = true;
    }
  }

  /// Starts [transport] while watching whether it is worth waiting for.
  ///
  /// Throws [_AbandonedAttempt] as soon as the bootstrap stops moving for
  /// [_directStallLimit] before it reaches [_relayFraction], reports a
  /// blockage that suggests censorship, or runs past [_directTimeLimit].
  /// Leaving the abandoned start running would hold the backend's serialized
  /// lifecycle, so the caller stops it.
  Future<TorProxyEndpoint> _startOrAbandon(TorTransport transport) async {
    final abandoned = Completer<TorProxyEndpoint>();
    void abandon() {
      if (!abandoned.isCompleted) {
        abandoned.completeError(const _AbandonedAttempt());
      }
    }

    var bestProgress = double.negativeInfinity;
    Timer? stall = Timer(_directStallLimit, abandon);
    final limit = Timer(_directTimeLimit, abandon);
    final progress = _embeddedTor.watch().listen((event) {
      if (event is! EmbeddedTorConnecting || event.transport != transport) {
        return;
      }
      if (event.diagnostic?.suggestsCensorship ?? false) return abandon();
      if (event.progress <= bestProgress) return;
      bestProgress = event.progress;
      stall?.cancel();
      stall = bestProgress >= _relayFraction
          ? null
          : Timer(_directStallLimit, abandon);
    });

    try {
      // Whichever settles first wins; the loser's late result is dropped.
      return await Future.any([
        _embeddedTor.start(transport),
        abandoned.future,
      ]);
    } finally {
      stall?.cancel();
      limit.cancel();
      // Not awaited: nothing depends on the watcher being gone, and the
      // attempt that follows must not queue behind it.
      unawaited(progress.cancel());
    }
  }

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
        when _lastSuccessfulTransport == TorTransport.snowflake =>
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

  static bool _shouldUseSnowflake(TorFailure failure) => switch (failure) {
    TorBootstrapTimeoutFailure() => true,
    TorBootstrapFailure(:final diagnostic) =>
      diagnostic?.suggestsCensorship ?? false,
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

/// Internal signal that an attempt was given up in favour of the next one.
final class _AbandonedAttempt implements Exception {
  const _AbandonedAttempt();
}
