import 'package:bb_mobile/features/tor_settings/ui/tor_settings_router.dart';
export 'tor_settings_scope.dart';
export 'tor_settings_panel.dart';
export 'tor_settings_bottom_sheet.dart';

class TorSettingsFacade {
  const TorSettingsFacade();

  String get settingsRouteName => TorSettingsRoute.torSettings.name;
}
