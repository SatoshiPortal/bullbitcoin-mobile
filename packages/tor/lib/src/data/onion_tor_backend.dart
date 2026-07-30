import 'dart:async';
import 'dart:io';

import 'package:bull_sdk/onion.dart' as onion;
import 'package:path_provider/path_provider.dart';

import '../domain/entities/tor_connection_state.dart';
import '../domain/entities/tor_proxy_endpoint.dart';
import '../domain/entities/tor_session.dart';
import '../domain/entities/tor_transport.dart';
import '../domain/ports/embedded_tor_port.dart';
import '../domain/tor_failure.dart';
import 'tor_logger.dart';

/// Platform adapter for the embedded Arti client shipped by `package:onion`.
final class OnionTorBackend implements EmbeddedTorPort {
  final TorLogger _log;
  onion.TorService? _service;
  StreamSubscription<onion.TorStatus>? _statusSubscription;
  final StreamController<EmbeddedTorEvent> _events =
      StreamController<EmbeddedTorEvent>.broadcast(sync: true);
  TorProxyEndpoint? _endpoint;
  TorTransport? _transport;
  TorDiagnostic? _lastDiagnostic;
  Future<void> _lifecycleTail = Future<void>.value();
  Future<void> _dormancyTail = Future<void>.value();
  int _generation = 0;
  bool _dormant = false;
  bool _snowflakeLease = false;

  OnionTorBackend(this._log);

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

    try {
      final support = await getApplicationSupportDirectory();
      final cache = await getApplicationCacheDirectory();
      final stateDir = await Directory('${support.path}/tor_state').create();
      final cacheDir = await Directory('${cache.path}/tor').create();

      _log.config('Starting embedded Tor with ${transport.name} transport...');
      final startedAt = DateTime.now();
      final service = switch (transport) {
        TorTransport.direct => await onion.TorService.start(
          stateDir: stateDir.path,
          cacheDir: cacheDir.path,
          socksPort: 0,
        ),
        TorTransport.snowflake => await _startWithSnowflake(
          stateDir.path,
          cacheDir.path,
        ),
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

      _statusSubscription = service.watchStatus().listen(
        (status) => _handleStatus(status, endpoint),
        onError: (Object error) {
          _log.warning('Embedded Tor status stream failed: $error');
          _publish(EmbeddedTorFailed(TorUnexpectedFailure(error.toString())));
        },
      );

      await service.bootstrap();
      if (generation != _generation) throw _cancelled();
      await _applyDormancy(service);
      if (!await service.proxyIsAlive()) {
        throw const TorBackendException(
          TorUnexpectedFailure(
            'Embedded SOCKS listener stopped after bootstrap',
          ),
        );
      }

      _publish(EmbeddedTorReady(endpoint, transport));
      _log.fine(
        'Embedded Tor ready in '
        '${DateTime.now().difference(startedAt).inSeconds}s on port '
        '${endpoint.port}',
      );
      return endpoint;
    } on TorBackendException {
      await _cleanup();
      rethrow;
    } on onion.TorFailure catch (error) {
      final failure = _mapFailure(error, _lastDiagnostic);
      await _cleanup();
      throw TorBackendException(failure);
    } catch (error) {
      await _cleanup();
      throw TorBackendException(TorUnexpectedFailure(error.toString()));
    }
  }

  void _handleStatus(onion.TorStatus status, TorProxyEndpoint endpoint) {
    final blockage = status.blockage;
    final diagnostic = blockage == null ? null : _mapDiagnostic(blockage.kind);
    final transport = _mapTransport(status.transport);
    _lastDiagnostic = diagnostic;
    final percent = (status.fraction * 100).round();
    _log.fine(
      'Embedded Tor bootstrap $percent%'
      '${diagnostic == null ? '' : ' (${diagnostic.name})'}',
    );

    _publish(
      status.readyForTraffic
          ? EmbeddedTorReady(endpoint, transport)
          : EmbeddedTorConnecting(
              progress: status.fraction,
              transport: transport,
              diagnostic: diagnostic,
            ),
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

  static TorFailure _mapFailure(
    onion.TorFailure failure,
    TorDiagnostic? diagnostic,
  ) => switch (failure.kind) {
    onion.TorFailureKind.configuration ||
    onion.TorFailureKind.listenerBind => TorStorageFailure(failure.logMessage),
    onion.TorFailureKind.bootstrap => TorBootstrapFailure(
      failure.logMessage,
      diagnostic,
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
      final session = await service.openSession(socksPort: 0);
      return TorSession(
        TorProxyEndpoint(
          host: InternetAddress.loopbackIPv4.address,
          port: await session.socksPort(),
        ),
        transport,
        session.stop,
      );
    } on onion.TorFailure catch (error) {
      throw TorBackendException(_mapFailure(error, _lastDiagnostic));
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
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
    await _statusSubscription?.cancel();
    _statusSubscription = null;
    final service = _service;
    final snowflakeLease = _snowflakeLease;
    _service = null;
    _endpoint = null;
    _transport = null;
    _lastDiagnostic = null;
    _snowflakeLease = false;
    try {
      await service?.stop();
    } finally {
      if (snowflakeLease) await onion.SnowflakeTransport.stop();
    }
  }

  Future<onion.TorService> _startWithSnowflake(
    String stateDir,
    String cacheDir,
  ) async {
    final snowflakePort = await onion.SnowflakeTransport.start();
    _snowflakeLease = true;
    return onion.TorService.startWithSnowflake(
      stateDir: stateDir,
      cacheDir: cacheDir,
      socksPort: 0,
      snowflakePort: snowflakePort,
    );
  }

  TorBackendException _cancelled() => const TorBackendException(
    TorUnexpectedFailure('Embedded Tor start was cancelled'),
  );
}
