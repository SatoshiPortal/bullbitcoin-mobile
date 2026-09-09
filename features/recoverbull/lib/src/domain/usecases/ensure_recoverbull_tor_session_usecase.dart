import '../recoverbull_failure.dart';
import '../recoverbull_tor_route.dart';
import 'dart:io';

import 'package:primitives/primitives.dart';
import 'package:bull_tor/tor.dart';

import '../recoverbull_settings_port.dart';
import '../../public/recoverbull.dart' show RecoverBullTiming;

/// Opens the route RecoverBull reaches the key server through, behind its own
/// failure boundary.
///
/// The external proxy wins when the user enabled it. That is not only what the
/// app promised before embedded Tor existed — it is the only thing that works
/// for a local SOCKS5 proxy user: a system-level VPN can put every socket this
/// app opens inside its own tunnel, and embedded Tor cannot bootstrap through
/// another Tor. Loopback is the way out — a connection to 127.0.0.1 does not
/// traverse the tunnel interface, so the proxy hop stays local and only the
/// configured proxy carries the traffic.
class EnsureRecoverBullTorSessionUsecase {
  final EmbeddedTor _embeddedTor;
  final RecoverBullSettingsPort _settingsRepository;
  final Tor _tor;
  final TorHttpClientFactory _torHttpClientFactory;
  final TorRoutePool? routePool;
  final void Function(TorRoutePoolEvent event)? routePoolEvent;
  final RecoverBullTiming? timing;

  const EnsureRecoverBullTorSessionUsecase(
    this._embeddedTor,
    this._settingsRepository,
    this._tor, {
    this.timing,
    TorHttpClientFactory? torHttpClientFactory,
    this.routePool,
    this.routePoolEvent,
  }) : _torHttpClientFactory =
           torHttpClientFactory ?? const TorHttpClientFactory();

  Future<Result<RecoverBullTorRoute, RecoverBullFailure>> execute({
    bool restartEmbedded = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    var routeOutcome = 'opened';
    void reportRouteEvent(TorRoutePoolEvent event) {
      if (event.type == TorRoutePoolEventType.attached) {
        routeOutcome = 'attached';
      }
      routePoolEvent?.call(event);
    }

    void reportTiming(String outcome) {
      try {
        timing?.call(
          'tor_route_acquire',
          stopwatch.elapsedMilliseconds,
          outcome,
        );
      } catch (_) {
        // Timing is diagnostic only and must not alter route acquisition.
      }
    }

    try {
      final settings = await _settingsRepository.fetch();
      if (settings.useTorProxy) {
        final TorProxyEndpoint endpoint;
        try {
          endpoint = TorProxyEndpoint(
            host: InternetAddress.loopbackIPv4.address,
            port: settings.torProxyPort,
          );
        } on ArgumentError {
          reportTiming('failure');
          return const Err(ExternalTorProxyUnavailableFailure());
        }
        final shared = routePool == null
            ? null
            : await routePool!.acquire(
                key: 'external:${endpoint.host}:${endpoint.port}',
                open: () async {
                  final verified = await _tor.external.verify(endpoint);
                  if (verified case TorReady(:final route)) return route;
                  throw const TorBackendException(
                    TorUnexpectedFailure('External Tor unavailable'),
                  );
                },
                close: () async {},
                onEvent: reportRouteEvent,
              );
        final routeState = routePool == null
            ? await _tor.external.verify(endpoint)
            : TorReady(shared!.route);
        try {
          switch (routeState) {
            case TorReady(:final route):
              final failureRecorder = TorConnectionFailureRecorder();
              final value = Ok<RecoverBullTorRoute, RecoverBullFailure>(
                RecoverBullTorRoute(
                  shared?.route ?? route,
                  shared?.release ?? (() async {}),
                  _torHttpClientFactory.create(
                    route.endpoint,
                    failureRecorder: failureRecorder,
                  ),
                  connectionFailureRecorder: failureRecorder,
                ),
              );
              // Keep each caller's wait duration, but only call a shared wait an
              // attachment in the timing log rather than a route acquisition.
              reportTiming(routePool == null ? 'success' : routeOutcome);
              return value;
            case TorUnavailable(:final failure):
              reportTiming('failure');
              return Err(
                ExternalTorProxyUnavailableFailure(failure.logMessage),
              );
            case _:
              reportTiming('failure');
              return const Err(ExternalTorProxyUnavailableFailure());
          }
        } catch (_) {
          try {
            await shared?.release();
          } catch (_) {}
          rethrow;
        }
      }

      final readiness = restartEmbedded
          ? await _embeddedTor.retry()
          : await _embeddedTor.ensureReady();
      final Result<RecoverBullTorRoute, RecoverBullFailure>
      result = await switch (readiness) {
        TorReady(:final route) when route.source == TorSource.embedded =>
          _openSession(onEvent: reportRouteEvent),
        TorUnavailable(:final failure) => Err(
          KeyServerUnavailableFailure(failure.logMessage),
        ),
        final state => Err(
          KeyServerUnavailableFailure(
            'Tor did not reach a terminal ready state: ${state.runtimeType}',
          ),
        ),
      };
      reportTiming(
        result is! Ok
            ? 'failure'
            : routePool == null
            ? 'success'
            : routeOutcome,
      );
      return result;
    } on TorBackendException catch (error) {
      reportTiming('failure');
      return Err(KeyServerUnavailableFailure(error.failure.logMessage));
    } on Exception catch (error) {
      reportTiming('failure');
      return Err(KeyServerUnavailableFailure(error.toString()));
    }
  }

  Future<Result<RecoverBullTorRoute, RecoverBullFailure>> _openSession({
    required void Function(TorRoutePoolEvent event) onEvent,
  }) async {
    TorSession? session;
    try {
      final shared = routePool == null
          ? null
          : await routePool!.acquire(
              key: 'embedded',
              open: () async {
                session = await _embeddedTor.sessions.open();
                return TorRoute(
                  source: TorSource.embedded,
                  endpoint: session!.endpoint,
                  evidence: TorReadinessEvidence.embeddedBootstrap,
                  transport: session!.transport,
                );
              },
              close: () async => session?.close(),
              onEvent: onEvent,
            );
      if (shared == null) session = await _embeddedTor.sessions.open();
      try {
        final failureRecorder = TorConnectionFailureRecorder();
        final route =
            shared?.route ??
            TorRoute(
              source: TorSource.embedded,
              endpoint: session!.endpoint,
              evidence: TorReadinessEvidence.embeddedBootstrap,
              transport: session!.transport,
            );
        return Ok(
          RecoverBullTorRoute(
            route,
            shared?.release ?? session!.close,
            _torHttpClientFactory.create(
              route.endpoint,
              failureRecorder: failureRecorder,
            ),
            connectionFailureRecorder: failureRecorder,
          ),
        );
      } catch (_) {
        try {
          await (shared?.release() ?? session?.close());
        } catch (_) {}
        rethrow;
      }
    } on TorBackendException catch (error) {
      return Err(KeyServerUnavailableFailure(error.failure.logMessage));
    } on Exception catch (error) {
      return Err(KeyServerUnavailableFailure(error.toString()));
    }
  }
}
