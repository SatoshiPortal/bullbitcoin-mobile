import 'dart:io';

import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_tor_route.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_tor/tor.dart';

/// Opens the route RecoverBull reaches the key server through, behind its own
/// failure boundary.
///
/// The external proxy wins when the user enabled it. That is not only what the
/// app promised before embedded Tor existed — it is the only thing that works
/// for an Orbot user: Orbot's "Full Device VPN" mode puts every socket this app
/// opens inside its own Tor tunnel, and embedded Tor cannot bootstrap through
/// another Tor. Measured on a Pixel 5: 51s to ready without the VPN, versus
/// stuck at 8% and then a Snowflake attempt that never completed with it.
/// Loopback is the way out — a connection to 127.0.0.1 does not traverse the tun
/// interface, so the proxy hop stays local and only Orbot's Tor carries the
/// traffic. One circuit instead of two nested ones.
class EnsureRecoverBullTorSessionUsecase {
  final EmbeddedTor _embeddedTor;
  final SettingsRepository _settingsRepository;
  final VerifyExternalTorUsecase _verifyExternalTorUsecase;

  const EnsureRecoverBullTorSessionUsecase(
    this._embeddedTor,
    this._settingsRepository,
    this._verifyExternalTorUsecase,
  );

  Future<Result<RecoverBullTorRoute, RecoverBullCoreFailure>> execute({
    bool restartEmbedded = false,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      if (settings.useTorProxy) return _external(settings.torProxyPort);

      final readiness = restartEmbedded
          ? await _embeddedTor.retry()
          : await _embeddedTor.ensureReady();
      return switch (readiness) {
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
    } on TorBackendException catch (error) {
      return Err(KeyServerUnavailableFailure(error.failure.logMessage));
    } on Exception catch (error) {
      return Err(KeyServerUnavailableFailure(error.toString()));
    }
  }

  /// No circuit isolation to release, hence the no-op close: the proxy is not
  /// ours to start or stop, and stopping it would break every other consumer.
  Future<Result<RecoverBullTorRoute, RecoverBullCoreFailure>> _external(
    int port,
  ) async {
    try {
      final endpoint = TorProxyEndpoint(
        host: InternetAddress.loopbackIPv4.address,
        port: port,
      );
      final verification = await _verifyExternalTorUsecase.execute(endpoint);
      if (verification case TorUnavailable(:final failure)) {
        return Err(ExternalTorProxyUnavailableFailure(failure.logMessage));
      }
      if (verification is! TorReady) {
        return const Err(ExternalTorProxyUnavailableFailure());
      }
      return Ok(RecoverBullTorRoute(verification.route, () async {}));
    } on ArgumentError catch (error) {
      // A port persisted outside 1-65535 would otherwise throw out of a
      // Result-returning use case. `RangeError` is an `ArgumentError`, so this
      // single clause covers the endpoint's two validation failures.
      return Err(ExternalTorProxyUnavailableFailure(error.toString()));
    }
  }

  Future<Result<RecoverBullTorRoute, RecoverBullCoreFailure>>
  _openSession() async {
    try {
      final session = await _embeddedTor.sessions.open();
      return Ok(
        RecoverBullTorRoute(
          TorRoute(
            source: TorSource.embedded,
            endpoint: session.endpoint,
            evidence: TorReadinessEvidence.embeddedBootstrap,
            transport: session.transport,
          ),
          session.close,
        ),
      );
    } on TorBackendException catch (error) {
      return Err(KeyServerUnavailableFailure(error.failure.logMessage));
    } catch (error) {
      return Err(KeyServerUnavailableFailure(error.toString()));
    }
  }
}
