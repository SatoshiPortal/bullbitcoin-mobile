import 'dart:io';

import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bull_tor/tor.dart';

/// Verifies an external SOCKS proxy before making it the configured route.
class UpdateTorProxyUsecase {
  final SettingsRepository _settingsRepository;
  final VerifyExternalTorUsecase _verifyExternalTorUsecase;
  Future<void> _persistenceQueue = Future<void>.value();

  UpdateTorProxyUsecase(
    this._settingsRepository,
    this._verifyExternalTorUsecase,
  );

  Future<TorConnectionState> execute({
    required bool useTorProxy,
    required int torProxyPort,
    bool Function()? isCurrent,
  }) async {
    if (!useTorProxy) {
      try {
        await _persist(() async {
          await _settingsRepository.setTorProxy(
            enabled: false,
            port: torProxyPort,
          );
        }, isCurrent);
      } catch (_) {
        return const TorUnavailable(
          source: TorSource.external,
          failure: TorStorageFailure(),
        );
      }
      return const TorStopped(TorSource.external);
    }

    final TorProxyEndpoint endpoint;
    try {
      endpoint = TorProxyEndpoint(
        host: InternetAddress.loopbackIPv4.address,
        port: torProxyPort,
      );
    } on ArgumentError catch (error) {
      return TorUnavailable(
        source: TorSource.external,
        failure: TorExternalProxyUnavailableFailure(error.toString()),
      );
    }

    final connection = await _verifyExternalTorUsecase.execute(endpoint);
    if (connection is! TorReady) return connection;

    try {
      await _persist(() async {
        await _settingsRepository.setTorProxy(
          enabled: true,
          port: torProxyPort,
        );
      }, isCurrent);
    } catch (_) {
      return const TorUnavailable(
        source: TorSource.external,
        failure: TorStorageFailure(),
      );
    }
    return connection;
  }

  Future<void> _persist(
    Future<void> Function() operation,
    bool Function()? isCurrent,
  ) {
    final queued = _persistenceQueue.then((_) async {
      if (isCurrent != null && !isCurrent()) return;
      await operation();
    });
    _persistenceQueue = queued.catchError((_) {});
    return queued;
  }
}
