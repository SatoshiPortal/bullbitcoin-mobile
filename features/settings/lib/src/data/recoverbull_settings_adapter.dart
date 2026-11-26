import 'dart:async';
import 'dart:io';

import 'package:preferences/preferences.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_tor/tor.dart';

import '../domain/regtest_recoverbull_profile.dart';

/// Settings owns environment selection, proxy preference and live consent.
final class RecoverBullSettingsAdapter
    implements
        RecoverBullRoutePort,
        RecoverBullEnvironmentPort,
        RecoverBullPermissionPort {
  final Preferences _settings;
  final RecoverBullPreferences _preferences;
  final EmbeddedTor _embedded;
  final Tor _tor;
  final RegtestRecoverBullProfile? regtestProfile;
  StreamController<TorConnectionState>? _regtestStates;
  TorConnectionState _regtestState = const TorUninitialized();
  bool _closed = false;

  RecoverBullSettingsAdapter(
    this._settings,
    this._preferences,
    this._embedded,
    this._tor, {
    this.regtestProfile,
  });

  bool _matchesRuntime(SettingsEntity settings) {
    final regtest = settings.environment == Environment.regtest;
    return regtest == (regtestProfile != null) &&
        (!regtest ||
            (settings.isSuperuser == true &&
                settings.isDevModeEnabled == true));
  }

  Uri get configuredServer =>
      regtestProfile?.server ?? Uri.parse(recoverBullDefaultServerUrl);

  @override
  Future<Result<({bool granted, int revision}), RecoverBullFailure>>
  readPermission() async {
    if (!await _runtimeIsCurrent()) {
      return const Err(VaultContextChangedFailure());
    }
    final permission = await _preferences.readState(
      regtest: regtestProfile != null,
    );
    if (!await _runtimeIsCurrent()) {
      return const Err(VaultContextChangedFailure());
    }
    return switch (permission) {
      Ok(value: final value?) => Ok(value),
      _ => const Err(VaultStorageFailure()),
    };
  }

  @override
  Future<Result<void, RecoverBullFailure>> savePermission(bool granted) async {
    if (!await _runtimeIsCurrent()) {
      return const Err(VaultContextChangedFailure());
    }
    final saved = await _preferences.setPermission(
      granted,
      regtest: regtestProfile != null,
    );
    return saved.mapErr(
      (failure) => failure is PreferencesContextChangedFailure
          ? const VaultContextChangedFailure()
          : const VaultStorageFailure(),
    );
  }

  Future<bool> _runtimeIsCurrent() async {
    if (_closed) return false;
    try {
      return switch (await _settings.fetch()) {
        Ok(:final value) => !_closed && _matchesRuntime(value),
        Err() => false,
      };
    } on Exception {
      return false;
    }
  }

  @override
  Future<Result<BitcoinNetwork, RecoverBullFailure>> currentNetwork() async {
    try {
      final settings = (await _settings.fetch()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      );
      if (!_matchesRuntime(settings)) {
        return const Err(VaultContextChangedFailure());
      }
      return Ok(BitcoinNetwork.fromName(settings.environment.name));
    } on Exception {
      log.warning('recoverbull.environment.read.failed');
      return const Err(VaultStorageFailure());
    }
  }

  @override
  Stream<TorConnectionState> watch() {
    if (regtestProfile?.endpoint == null) {
      return _embedded.states;
    }
    if (_closed) {
      return Stream.value(const TorStopped(TorSource.external));
    }
    return Stream.multi((controller) {
      controller.add(_regtestState);
      final states = _regtestStates ??=
          StreamController<TorConnectionState>.broadcast(sync: true);
      final subscription = states.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    }, isBroadcast: true);
  }

  void _publish(TorConnectionState state) {
    if (_closed) {
      return;
    }
    _regtestState = state;
    _regtestStates?.add(state);
  }

  @override
  bool get snowflakeAvailable =>
      regtestProfile?.endpoint == null &&
      _embedded.mode == TorTransportMode.automatic;

  @override
  Future<Result<RecoverBullRoute, RecoverBullFailure>> open({
    bool restartEmbedded = false,
    bool viaSnowflake = false,
  }) async {
    try {
      if (_closed) {
        return const Err(VaultCancelledFailure());
      }
      final settings = (await _settings.fetch()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      );
      if (!_matchesRuntime(settings)) {
        return const Err(VaultContextChangedFailure());
      }
      // A local stack's fixture onion is only reachable through its own
      // proxy; a hosted onion service takes the ordinary Tor route below.
      final regtestProxy = regtestProfile?.endpoint;
      if (regtestProxy != null) {
        _publish(const TorConnecting(source: TorSource.external));
        final ready = await _tor.external.verify(regtestProxy);
        if (!await _runtimeIsCurrent()) {
          return const Err(VaultContextChangedFailure());
        }
        _publish(ready);
        if (ready is! TorReady || ready.route.source != TorSource.external) {
          return const Err(ExternalTorProxyUnavailableFailure());
        }
        return Ok(RecoverBullRoute(ready.route, () async {}));
      }
      if (settings.useTorProxy) {
        final TorProxyEndpoint endpoint;
        try {
          endpoint = TorProxyEndpoint(
            host: InternetAddress.loopbackIPv4.address,
            port: settings.torProxyPort,
          );
        } on ArgumentError {
          return const Err(ExternalTorProxyUnavailableFailure());
        }
        final ready = await _tor.external.verify(endpoint);
        if (!await _runtimeIsCurrent()) {
          return const Err(VaultContextChangedFailure());
        }
        return switch (ready) {
          TorReady(:final route) => Ok(RecoverBullRoute(route, () async {})),
          _ => const Err(ExternalTorProxyUnavailableFailure()),
        };
      }
      // New route never restarts the shared engine or another flow's circuit;
      // only Retry after a failed or stalled bootstrap asks for a restart.
      final ready = restartEmbedded || viaSnowflake
          ? await _embedded.retry(snowflake: viaSnowflake)
          : await _embedded.ensureReady();
      if (!await _runtimeIsCurrent()) {
        return const Err(VaultContextChangedFailure());
      }
      if (ready is! TorReady || ready.route.source != TorSource.embedded) {
        return const Err(KeyServerFailure(KeyServerFailureKind.unavailable));
      }
      final session = await _embedded.sessions.open();
      if (!await _runtimeIsCurrent()) {
        await session.close();
        return const Err(VaultContextChangedFailure());
      }
      return Ok(
        RecoverBullRoute(
          TorRoute(
            source: TorSource.embedded,
            endpoint: session.endpoint,
            evidence: TorReadinessEvidence.embeddedBootstrap,
            transport: session.transport,
          ),
          session.close,
        ),
      );
    } on Exception {
      log.warning('recoverbull.route.open.failed');
      return const Err(KeyServerFailure(KeyServerFailureKind.unavailable));
    }
  }

  Future<void> close() async {
    _closed = true;
    await _regtestStates?.close();
  }
}
