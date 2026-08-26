import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_tor_route.dart';
import 'dart:io';

import 'package:primitives/primitives.dart';
import 'package:bull_tor/tor.dart';

import '../ports.dart';
import '../../public/recoverbull.dart'
    show RecoverBullLogger, RecoverBullTiming;

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
  final RecoverBullLogger? logger;
  final RecoverBullTiming? timing;

  const EnsureRecoverBullTorSessionUsecase(
    this._embeddedTor,
    this._settingsRepository,
    this._tor, {
    this.logger,
    this.timing,
    TorHttpClientFactory? torHttpClientFactory,
  }) : _torHttpClientFactory =
           torHttpClientFactory ?? const TorHttpClientFactory();

  Future<Result<RecoverBullTorRoute, RecoverBullCoreFailure>> execute({
    bool restartEmbedded = false,
  }) async {
    final stopwatch = Stopwatch()..start();
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
        switch (await _tor.external.verify(endpoint)) {
          case TorReady(:final route):
            final value = Ok<RecoverBullTorRoute, RecoverBullCoreFailure>(
              RecoverBullTorRoute(
                route,
                () async {},
                _torHttpClientFactory.create(route.endpoint),
              ),
            );
            reportTiming('success');
            return value;
          case TorUnavailable(:final failure):
            reportTiming('failure');
            return Err(ExternalTorProxyUnavailableFailure(failure.logMessage));
          case _:
            reportTiming('failure');
            return const Err(ExternalTorProxyUnavailableFailure());
        }
      }

      final readiness = restartEmbedded
          ? await _embeddedTor.retry()
          : await _embeddedTor.ensureReady();
      final Result<RecoverBullTorRoute, RecoverBullCoreFailure>
      result = await switch (readiness) {
        TorReady(:final route) when route.source == TorSource.embedded =>
          _openSession(),
        TorUnavailable(:final failure) => Err(
          KeyServerUnavailableFailure(failure.logMessage),
        ),
        final state => Err(
          KeyServerUnavailableFailure(
            'Tor did not reach a terminal ready state: ${state.runtimeType}',
          ),
        ),
      };
      reportTiming(result is Ok ? 'success' : 'failure');
      return result;
    } on TorBackendException catch (error) {
      reportTiming('failure');
      return Err(KeyServerUnavailableFailure(error.failure.logMessage));
    } on Exception catch (error) {
      reportTiming('failure');
      return Err(KeyServerUnavailableFailure(error.toString()));
    }
  }

  Future<Result<RecoverBullTorRoute, RecoverBullCoreFailure>>
  _openSession() async {
    try {
      final session = await _embeddedTor.sessions.open();
      try {
        return Ok(
          RecoverBullTorRoute(
            TorRoute(
              source: TorSource.embedded,
              endpoint: session.endpoint,
              evidence: TorReadinessEvidence.embeddedBootstrap,
              transport: session.transport,
            ),
            session.close,
            _torHttpClientFactory.create(session.endpoint),
          ),
        );
      } catch (_) {
        try {
          await session.close();
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
