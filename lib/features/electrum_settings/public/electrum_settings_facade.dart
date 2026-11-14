import 'package:bb_mobile/features/electrum_settings/frameworks/ui/routing/electrum_settings_router.dart';

export '../background_setup.dart' show createBackgroundWalletConnections;

class ElectrumSettingsFacade {
  const ElectrumSettingsFacade();

  String get settingsRouteName => ElectrumSettingsRoute.electrumSettings.name;
}
