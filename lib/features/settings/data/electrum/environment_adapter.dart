import 'package:electrum/setup.dart';
import 'package:preferences/preferences.dart';

class EnvironmentAdapter {
  final SettingsRepository Function() _settingsRepository;

  EnvironmentAdapter({required this._settingsRepository});

  Future<ElectrumPreferences> readPreferences() async {
    final settings = await _settingsRepository().fetch();
    return (
      isSuperuser: settings.isSuperuser,
      isDevModeEnabled: settings.isDevModeEnabled,
      useTorProxy: settings.useTorProxy,
      torProxyPort: settings.torProxyPort,
    );
  }
}
