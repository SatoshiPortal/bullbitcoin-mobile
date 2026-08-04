import 'package:bb_mobile/features/app_startup/domain/app_startup_wallet_port.dart';
import 'package:bull_tor/tor.dart';

/// Eagerly warms Tor only for an existing RecoverBull backup.
class InitializeRequiredTorUsecase {
  final AppStartupWalletPort _walletPort;
  final EnsureTorReadyUsecase _ensureTorReadyUsecase;

  const InitializeRequiredTorUsecase(
    this._walletPort,
    this._ensureTorReadyUsecase,
  );

  Future<TorConnectionState?> execute() async {
    if (!await _walletPort.hasMainnetBitcoinEncryptedBackup()) {
      return null;
    }
    return _ensureTorReadyUsecase.execute();
  }
}
