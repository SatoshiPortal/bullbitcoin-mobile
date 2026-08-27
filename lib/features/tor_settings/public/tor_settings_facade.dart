import 'package:bb_mobile/features/tor_settings/ui/tor_settings_router.dart';
export '../ui/widgets/embedded_tor_status_indicator.dart';
export 'embedded_tor_status_scope.dart';
export 'tor_settings_scope.dart';

class TorSettingsFacade {
  const TorSettingsFacade();

  String get settingsRouteName => TorSettingsRoute.torSettings.name;
}
