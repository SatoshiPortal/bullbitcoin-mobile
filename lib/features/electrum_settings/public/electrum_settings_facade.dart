import 'package:bb_mobile/features/electrum_settings/frameworks/ui/routing/electrum_settings_router.dart';
import 'package:bb_mobile/features/electrum_settings/domain/usecases/has_active_custom_bitcoin_onion_server_usecase.dart';

class ElectrumSettingsFacade {
  final HasActiveCustomBitcoinOnionServerUsecase
  _hasActiveCustomBitcoinOnionServerUsecase;

  const ElectrumSettingsFacade({
    required this._hasActiveCustomBitcoinOnionServerUsecase,
  });

  String get settingsRouteName => ElectrumSettingsRoute.electrumSettings.name;

  Future<bool> hasActiveCustomBitcoinOnionServer() =>
      _hasActiveCustomBitcoinOnionServerUsecase.execute();
}
