import 'package:bb_mobile/features/app_startup/domain/app_startup_wallet_port.dart';
import 'package:bb_mobile/features/electrum_settings/public/electrum_settings_facade.dart';

final class GetTorStatusVisibilityUsecase {
  final AppStartupWalletPort _walletPort;
  final ElectrumSettingsFacade _electrumSettingsFacade;

  const GetTorStatusVisibilityUsecase(
    this._walletPort,
    this._electrumSettingsFacade,
  );

  Future<bool> execute() async {
    final backup = await _safe(_walletPort.hasTestedRecoverBullBackup);
    final onion = await _safe(
      _electrumSettingsFacade.hasActiveCustomBitcoinOnionServer,
    );
    return backup || onion;
  }

  Future<bool> _safe(Future<bool> Function() operation) async {
    try {
      return await operation();
    } on Exception {
      return false;
    }
  }
}
