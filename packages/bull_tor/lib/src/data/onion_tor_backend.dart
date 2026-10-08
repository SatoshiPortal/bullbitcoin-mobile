import 'dart:async';
import 'dart:io';

import 'package:bull_sdk/onion.dart' as onion;
import 'package:meta/meta.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/entities/tor_connection_state.dart';
import '../domain/entities/tor_proxy_endpoint.dart';
import '../domain/entities/tor_session.dart';
import '../domain/entities/tor_transport.dart';
import '../domain/ports/embedded_tor_port.dart';
import '../domain/tor_connect_budget.dart';
import '../domain/tor_failure.dart';
import 'onion_client_launcher.dart';
import 'tor_logger.dart';

/// What Bull lets its embedded Tor listener relay.
///
/// `package:onion` defaults to [onion.SocksPolicy.any] — a Tor proxy that
/// refuses the clearnet is not a Tor proxy, and narrowing it is the embedding
/// application's call, not the library's. This is that call.
///
/// Bull only ever reaches hidden services this way: the RecoverBull key
/// server, and `.onion` Electrum servers. Everything else in the app talks
/// clearnet and does not go through here. The listener is a loopback TCP port
/// with no authentication, so any process on the device that finds it can use
/// it; refusing non-onion destinations bounds what that is worth to a hostile
/// local app. It narrows the exposure — it does not close it. Closing it needs
/// SOCKS credentials, which `bdk_dart` cannot carry on the Electrum path
/// today, or an `AF_UNIX` socket.
const _socksPolicy = onion.SocksPolicy.onionOnly;

/// [torConnectBudget] as the SDK takes it, applied to the client and every session alike.
final _connectTimeoutMs = BigInt.from(torConnectBudget.inMilliseconds);

/// How long to wait, once `bootstrap()` returns, for Arti to report it can
/// carry traffic.
const _trafficReadyTimeout = Duration(seconds: 60);

/// How long readiness is withheld after Arti first reports `readyForTraffic`.
///
/// Arti says it can carry traffic before a first onion connection actually succeeds, so announcing it at once sent requests into a client that failed them. The hold is applied once per bootstrap, not on directory-refresh republications.
const defaultReadinessHold = Duration(seconds: 5);

/// Platform adapter for the embedded Arti client shipped by `package:onion`.
final class OnionTorBackend implements EmbeddedTorPort {
  final TorLogger _log;
  final OnionClientLauncher _launcher;
  final Future<TorDirectories> Function() _directories;
  onion.TorService? _service;
  StreamSubscription<onion.TorStatus>? _statusSubscription;
  final StreamController<EmbeddedTorEvent> _events =
      StreamController<EmbeddedTorEvent>.broadcast(sync: true);
  TorProxyEndpoint? _endpoint;
  TorTransport? _transport;
  TorDiagnostic? _lastDiagnostic;
  String? _lastReadinessLog;
  Completer<void> _trafficReady = _pendingTrafficReady();
  Completer<void> _holdRelease = Completer<void>();
  final Duration _readinessHold;
  final Future<void> Function(Duration) _wait;

  /// Whether this bootstrap has served its readiness hold; until then Arti's readiness is republished as full progress, not as ready.
  bool _announced = false;
  TorBootstrapDetail? _lastDetail;
  Future<void> _lifecycleTail = Future<void>.value();
  Future<void> _dormancyTail = Future<void>.value();
  int _generation = 0;
  bool _dormant = false;
  bool _snowflakeLease = false;

  OnionTorBackend(
    this._log, {
    this._launcher = const NativeOnionClientLauncher(),
    this._directories = appTorDirectories,
    this._readinessHold = defaultReadinessHold,
    Future<void> Function(Duration)? wait,
  }) : _wait = wait ?? Future<void>.delayed;

  static Future<void> initialize() => onion.OnionCore.init();

  @override
  Stream<EmbeddedTorEvent> watch() => _events.stream;

  @override
  Future<TorProxyEndpoint> start(TorTransport transport) {
    final generation = ++_generation;
    return _serialize(() => _start(generation, transport));
  }

  @override
  Future<bool> isAlive() async {
    final service = _service;
    return service != null && await service.proxyIsAlive();
  }

  @override
  Future<void> setDormant(bool dormant) async {
    _dormant = dormant;
    final service = _service;
    if (service != null) await _applyDormancy(service);
  }

  Future<TorProxyEndpoint> _start(
    int generation,
    TorTransport transport,
  ) async {
    if (generation != _generation) throw _cancelled();
    final existingService = _service;
    final existingEndpoint = _endpoint;
    if (existingService != null &&
        existingEndpoint != null &&
        _transport == transport &&
        await existingService.proxyIsAlive()) {
      if (generation != _generation) throw _cancelled();
      return existingEndpoint;
    }

    await _cleanup();
    if (generation != _generation) throw _cancelled();
    _publish(const EmbeddedTorStopped());
    _publish(EmbeddedTorConnecting(progress: 0, transport: transport));
    _lastDiagnostic = null;
    _lastDetail = null;

    try {
      final directories = await _directories();
      final stateDir = directories.stateFor(transport);
      final cacheDir = directories.cache;
      await Directory(stateDir).create(recursive: true);
      await Directory(cacheDir).create(recursive: true);

      _log.config('Starting embedded Tor with ${transport.name} transport...');
      final startedAt = DateTime.now();
      final service = switch (transport) {
        TorTransport.direct => await _launcher.startClient(
          OnionClientConfig(
            transport: transport,
            stateDir: stateDir,
            cacheDir: cacheDir,
          ),
          _socksPolicy,
        ),
        TorTransport.snowflake => await _startWithSnowflake(stateDir, cacheDir),
      };
      if (generation != _generation) {
        await service.stop();
        throw _cancelled();
      }
      // Store the handle before any subsequent await so stop() can abort a
      // bootstrap that is still in flight.
      _service = service;
      _transport = transport;
      final endpoint = TorProxyEndpoint(
        host: InternetAddress.loopbackIPv4.address,
        port: await service.socksPort(),
      );
      _endpoint = endpoint;

      _trafficReady = _pendingTrafficReady();
      _statusSubscription = service.watchStatus().listen(
        (status) => handleStatus(status, endpoint),
        onError: (Object error) {
          _log.warning('Embedded Tor status stream failed: $error');
          _publish(EmbeddedTorFailed(TorUnexpectedFailure(error.toString())));
        },
      );

      await service.bootstrap();
      if (generation != _generation) throw _cancelled();
      // `bootstrap()` returns once the directory is usable, before Arti
      // reports `readyForTraffic`; announcing readiness then sent the first
      // request into a client that was not ready yet.
      await waitForTraffic(_trafficReadyTimeout);
      if (generation != _generation) throw _cancelled();
      _log.fine(
        'Embedded Tor reports ready after '
        '${DateTime.now().difference(startedAt).inSeconds}s; holding readiness '
        'for ${_readinessHold.inSeconds}s',
      );
      await holdReadiness();
      if (generation != _generation) throw _cancelled();
      await _applyDormancy(service);
      if (!await service.proxyIsAlive()) {
        throw const TorBackendException(
          TorUnexpectedFailure(
            'Embedded SOCKS listener stopped after bootstrap',
          ),
        );
      }

      _announced = true;
      _publish(EmbeddedTorReady(endpoint, transport));
      _log.fine(
        'Embedded Tor ready in '
        '${DateTime.now().difference(startedAt).inSeconds}s on port '
        '${endpoint.port}',
      );
      return endpoint;
    } on TorBackendException catch (error) {
      _logStartFailure(transport, error.failure);
      await _cleanup();
      rethrow;
    } on onion.TorFailure catch (error) {
      final failure = failureFor(error, _lastDiagnostic, _lastDetail);
      _logStartFailure(transport, failure);
      await _cleanup();
      throw TorBackendException(failure);
    } catch (error) {
      final failure = TorUnexpectedFailure(error.toString());
      _logStartFailure(transport, failure);
      await _cleanup();
      throw TorBackendException(failure);
    }
  }

  /// Without this a failed start leaves no trace in a field log: the
  /// repository turns it into a state, and consumers keep only its type.
  void _logStartFailure(TorTransport transport, TorFailure failure) =>
      _log.warning(
        'Embedded Tor ${transport.name} start failed '
        '(${failure.runtimeType}): ${failure.logMessage}',
      );

  /// Completes once a status reports `readyForTraffic`, fails on [stop] or
  /// after [timeout].
  @visibleForTesting
  Future<void> waitForTraffic(Duration timeout) => _trafficReady.future.timeout(
    timeout,
    onTimeout: () => throw TorBackendException(
      TorBootstrapTimeoutFailure('Not ready for traffic after $timeout'),
    ),
  );

  /// Waits out [_readinessHold]; [stop] ends the wait early so a restart does not queue behind it.
  @visibleForTesting
  Future<void> holdReadiness() {
    final release = _holdRelease = Completer<void>();
    return Future.any([_wait(_readinessHold), release.future]);
  }

  @visibleForTesting
  void handleStatus(onion.TorStatus status, TorProxyEndpoint endpoint) {
    final blockage = status.blockage;
    final diagnostic = blockage == null ? null : _mapDiagnostic(blockage.kind);
    final transport = _mapTransport(status.transport);
    final detail = switch (eventFor(status, endpoint)) {
      EmbeddedTorConnecting(:final detail) => detail,
      _ => null,
    };
    _lastDiagnostic = diagnostic;
    _lastDetail = detail;
    if (status.readyForTraffic && !_trafficReady.isCompleted) {
      _trafficReady.complete();
    }
    final percent = (status.fraction * 100).round();
    // Arti reports every internal change; only a visible one is worth a line.
    final readinessLog =
        'Embedded Tor readiness ${status.readyForTraffic ? 'ready' : 'waiting'} '
        '($percent%)'
        '${diagnostic == null ? '' : ' (${diagnostic.name})'}';
    if (readinessLog != _lastReadinessLog) {
      _lastReadinessLog = readinessLog;
      _log.fine(readinessLog);
    }

    _publish(
      status.readyForTraffic && _announced
          ? EmbeddedTorReady(endpoint, transport)
          : EmbeddedTorConnecting(
              progress: status.readyForTraffic ? 1 : status.fraction,
              transport: transport,
              diagnostic: diagnostic,
              detail: detail,
            ),
    );
  }

  /// Maps one arti status snapshot to the event this port publishes.
  @visibleForTesting
  static EmbeddedTorEvent eventFor(
    onion.TorStatus status,
    TorProxyEndpoint endpoint,
  ) {
    final transport = _mapTransport(status.transport);
    if (status.readyForTraffic) return EmbeddedTorReady(endpoint, transport);

    final blockage = status.blockage;
    final diagnostic = blockage == null ? null : _mapDiagnostic(blockage.kind);
    final message = blockage?.message.trim();
    // A blockage that maps to no diagnostic is not a fault, and its message
    // would put a bogus explanation on screen.
    final blockageDetail =
        diagnostic == null || message == null || message.isEmpty
        ? null
        : message;
    // Arti's own wording, for display only: never branch on it.
    final stage = status.stage.trim();
    final stageDetail = stage.isEmpty ? null : stage;
    return EmbeddedTorConnecting(
      progress: status.fraction,
      transport: transport,
      diagnostic: diagnostic,
      detail: blockageDetail == null && stageDetail == null
          ? null
          : TorBootstrapDetail(blockage: blockageDetail, stage: stageDetail),
    );
  }

  /// Arti keeps reporting after [close]; dropping those events is normal, and
  /// the single guard here is what makes every call site safe.
  void _publish(EmbeddedTorEvent event) {
    if (_events.isClosed) return;
    _events.add(event);
  }

  static TorDiagnostic? _mapDiagnostic(onion.BlockageKind kind) =>
      switch (kind) {
        onion.BlockageKind.notStarted => null,
        onion.BlockageKind.offline => TorDiagnostic.offline,
        onion.BlockageKind.filtering => TorDiagnostic.filtering,
        onion.BlockageKind.cantReachTor => TorDiagnostic.cantReachTor,
        onion.BlockageKind.clockSkewed => TorDiagnostic.clockSkewed,
        onion.BlockageKind.cantBootstrap => TorDiagnostic.cantBootstrap,
        onion.BlockageKind.other => TorDiagnostic.unknown,
      };

  static TorTransport _mapTransport(onion.TorTransport transport) =>
      switch (transport) {
        onion.TorTransport.direct => TorTransport.direct,
        onion.TorTransport.snowflake => TorTransport.snowflake,
      };

  @visibleForTesting
  static TorFailure failureFor(
    onion.TorFailure failure,
    TorDiagnostic? diagnostic, [
    TorBootstrapDetail? detail,
  ]) => switch (failure.kind) {
    onion.TorFailureKind.configuration ||
    onion.TorFailureKind.listenerBind => TorStorageFailure(failure.logMessage),
    onion.TorFailureKind.bootstrap => TorBootstrapFailure(
      failure.logMessage,
      diagnostic,
      detail,
    ),
    onion.TorFailureKind.timeout => TorBootstrapTimeoutFailure(
      failure.logMessage,
    ),
    onion.TorFailureKind.connect ||
    onion.TorFailureKind.notRunning ||
    onion.TorFailureKind.unexpected => TorUnexpectedFailure(failure.logMessage),
  };

  @override
  Future<TorSession> openSession() async {
    final service = _service;
    final transport = _transport;
    if (service == null || transport == null || !await service.proxyIsAlive()) {
      throw const TorBackendException(
        TorUnexpectedFailure('Embedded Tor is not ready for a session'),
      );
    }

    try {
      final session = await service.openSessionWithConnectTimeout(
        socksPort: 0,
        policy: _socksPolicy,
        connectTimeoutMs: _connectTimeoutMs,
      );
      return TorSession(
        TorProxyEndpoint(
          host: InternetAddress.loopbackIPv4.address,
          port: await session.socksPort(),
        ),
        transport,
        session.stop,
      );
    } on onion.TorFailure catch (error) {
      throw TorBackendException(failureFor(error, _lastDiagnostic));
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    if (!_trafficReady.isCompleted) _trafficReady.completeError(_cancelled());
    if (!_holdRelease.isCompleted) _holdRelease.complete();
    // Interrupt bootstrap before joining the serialized lifecycle tail.
    // Waiting for `_start` first would make Retry wait for the very bootstrap
    // it is supposed to cancel.
    final service = _service;
    if (service != null) {
      try {
        await service.stop();
      } catch (error) {
        _log.warning('Failed to interrupt embedded Tor: $error');
      }
    }
    await _serialize(_stop);
  }

  Future<void> _stop() async {
    await _cleanup();
    _publish(const EmbeddedTorStopped());
  }

  @override
  Future<void> close() async {
    await stop();
    await _events.close();
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final previous = _lifecycleTail;
    final completed = Completer<void>();
    _lifecycleTail = completed.future;
    return previous
        .catchError((_) {})
        .then((_) => operation())
        .whenComplete(completed.complete);
  }

  Future<void> _applyDormancy(onion.TorService service) {
    final operation = _dormancyTail.catchError((_) {}).then((_) async {
      if (!identical(_service, service)) return;
      await service.setDormant(dormant: _dormant);
    });
    _dormancyTail = operation;
    return operation;
  }

  Future<void> _cleanup() async {
    // Nothing here may throw. `_cleanup` runs inside `_start`'s catch blocks,
    // so an escaping error would replace the mapped failure with a raw one —
    // and a `TorBootstrapTimeoutFailure` that arrives as `TorUnexpectedFailure`
    // no longer matches the automatic Snowflake fallback.
    try {
      await _statusSubscription?.cancel();
    } catch (error) {
      _log.warning('Failed to cancel the embedded Tor status stream: $error');
    }
    _statusSubscription = null;
    final service = _service;
    final snowflakeLease = _snowflakeLease;
    _service = null;
    _endpoint = null;
    _transport = null;
    _lastDiagnostic = null;
    _lastReadinessLog = null;
    _announced = false;
    _lastDetail = null;
    _snowflakeLease = false;
    try {
      await service?.stop();
    } catch (error) {
      _log.warning('Failed to stop the embedded Tor service: $error');
    } finally {
      if (snowflakeLease) await _launcher.stopSnowflakeProxy();
    }
  }

  Future<onion.TorService> _startWithSnowflake(
    String stateDir,
    String cacheDir,
  ) async {
    final snowflakePort = await _launcher.startSnowflakeProxy();
    _snowflakeLease = true;
    return _launcher.startClient(
      OnionClientConfig(
        transport: TorTransport.snowflake,
        stateDir: stateDir,
        cacheDir: cacheDir,
        snowflakePort: snowflakePort,
      ),
      _socksPolicy,
    );
  }

  /// Errors are observed by `_start` when it waits; marking the future handled
  /// keeps a cancellation nobody waits for from surfacing as uncaught.
  static Completer<void> _pendingTrafficReady() =>
      Completer<void>()..future.ignore();

  TorBackendException _cancelled() => const TorBackendException(
    TorUnexpectedFailure('Embedded Tor start was cancelled'),
  );
}

/// The directories the app's embedded Tor clients use.
Future<TorDirectories> appTorDirectories() async {
  final support = await getApplicationSupportDirectory();
  final cache = await getApplicationCacheDirectory();
  return torDirectoriesUnder(support: support.path, cache: cache.path);
}

/// The Tor directories under the app's [support] and [cache] directories.
@visibleForTesting
TorDirectories torDirectoriesUnder({
  required String support,
  required String cache,
}) => TorDirectories(
  directState: '$support/tor_state',
  snowflakeState: '$support/tor_state_snowflake',
  cache: '$cache/tor',
);
