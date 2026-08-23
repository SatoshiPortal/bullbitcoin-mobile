import 'package:bb_mobile/features/app_startup/domain/app_startup_wallet_port.dart';
import 'package:bb_mobile/core/tor/configured_external_tor.dart';
import 'package:bb_mobile/core/tor/resolve_configured_external_tor_usecase.dart';
import 'package:bull_tor/tor.dart';

/// Eagerly warms the configured Tor route for an existing RecoverBull backup.
class InitializeRequiredTorUsecase {
  final AppStartupWalletPort _walletPort;
  final EnsureTorReadyUsecase _ensureTorReadyUsecase;
  final ResolveConfiguredExternalTorUsecase
  _resolveConfiguredExternalTorUsecase;

  const InitializeRequiredTorUsecase(
    this._walletPort,
    this._ensureTorReadyUsecase,
    this._resolveConfiguredExternalTorUsecase,
  );

  Future<TorConnectionState?> execute() async {
    if (!await _walletPort.hasMainnetBitcoinEncryptedBackup()) {
      return null;
    }
    final configuredExternal = await _resolveConfiguredExternalTorUsecase
        .execute();
    switch (configuredExternal) {
      case ConfiguredExternalTorReady(:final route):
        return TorReady(route);
      case ConfiguredExternalTorUnavailable(:final failure):
        return TorUnavailable(source: TorSource.external, failure: failure);
      case ConfiguredExternalTorDisabled():
        break;
    }
    return _ensureTorReadyUsecase.execute();
  }
}
