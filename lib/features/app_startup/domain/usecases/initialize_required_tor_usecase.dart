import 'dart:io';

import 'package:bb_mobile/features/app_startup/domain/app_startup_wallet_port.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bull_tor/tor.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';

/// Eagerly warms the configured Tor route for an existing RecoverBull backup.
class InitializeRequiredTorUsecase {
  final AppStartupWalletPort _walletPort;
  final EnsureTorReadyUsecase _ensureTorReadyUsecase;
  final SettingsRepository _settingsRepository;
  final Tor _tor;

  const InitializeRequiredTorUsecase(
    this._walletPort,
    this._ensureTorReadyUsecase,
    this._settingsRepository,
    this._tor,
  );

  Future<TorConnectionState?> execute() async {
    switch (await _walletPort.hasMainnetBitcoinEncryptedBackup()) {
      case Ok(value: true):
        break;
      case Ok():
        return null;
      // Same as before this check returned a Result: an unknown answer skips
      // Tor rather than starting it. Logged, type only.
      case Err(:final failure):
        log.warning(
          'Encrypted backup check failed, skipping Tor: ${failure.runtimeType}',
        );
        return null;
    }
    final settings = await _settingsRepository.fetch();
    if (settings.useTorProxy) {
      final TorProxyEndpoint endpoint;
      try {
        endpoint = TorProxyEndpoint(
          host: InternetAddress.loopbackIPv4.address,
          port: settings.torProxyPort,
        );
      } on ArgumentError {
        return const TorUnavailable(
          source: TorSource.external,
          failure: TorExternalProxyUnavailableFailure(),
        );
      }
      return switch (await _tor.external.verify(endpoint)) {
        TorReady(:final route) => TorReady(route),
        TorUnavailable(:final failure) => TorUnavailable(
          source: TorSource.external,
          failure: failure,
        ),
        _ => const TorUnavailable(
          source: TorSource.external,
          failure: TorExternalProxyUnavailableFailure(),
        ),
      };
    }
    return _ensureTorReadyUsecase.execute();
  }
}
