import 'dart:async';

import '../domain/entities/tor_connection_state.dart';
import '../domain/entities/tor_proxy_endpoint.dart';
import '../domain/entities/tor_route.dart';
import '../domain/entities/tor_session.dart';
import '../domain/entities/tor_transport.dart';
import '../domain/ports/embedded_tor_port.dart';
import '../domain/tor_failure.dart';
import '../domain/tor_repository.dart';

final class TorRepositoryImpl implements TorRepository {
  final EmbeddedTorPort _embeddedTor;
  final Future<void> Function(TorTransport)? _onSuccessfulTransport;
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
  }) => TorRepositoryImpl._(
    embeddedTor,
    initialMode,
    lastSuccessfulTransport,
    onSuccessfulTransport,
  );

  TorRepositoryImpl._(
    this._embeddedTor,
    this._mode,
    this._lastSuccessfulTransport,
    this._onSuccessfulTransport,
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
  Future<TorConnectionState> retry() {
    final inFlight = _inFlight;
    if (inFlight != null && _retryInFlight) return inFlight;

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
    _generation++;
    await _embeddedSubscription?.cancel();
    await _embeddedTor.close();
    await _changes.close();
  }

  Future<TorConnectionState> _begin({required bool retry}) {
    final operation = _connect(++_generation);
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

  Future<TorConnectionState> _connect(int generation) async {
    await _embeddedSubscription?.cancel();
    _embeddedSubscription = null;

    // Stop before starting: a retry has to invalidate a client whose bootstrap
    // has not returned yet, instead of queueing behind it.
    await _embeddedTor.stop();
    if (!_isCurrent(generation)) return _current;

    _embeddedSubscription = _embeddedTor.watch().listen((event) {
      if (!_isCurrent(generation)) return;
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

    final attempts = _attempts();
    for (var index = 0; index < attempts.length; index++) {
      final transport = attempts[index];
      _emit(TorConnecting(source: TorSource.embedded, transport: transport));
      try {
        final endpoint = await _embeddedTor.start(transport);
        if (!_isCurrent(generation)) return _current;

        _lastSuccessfulTransport = transport;
        unawaited(_onSuccessfulTransport?.call(transport));
        final ready = _readyOn(endpoint, transport);
        _emit(ready);
        return ready;
      } on TorBackendException catch (error) {
        final hasFallback = index + 1 < attempts.length;
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
