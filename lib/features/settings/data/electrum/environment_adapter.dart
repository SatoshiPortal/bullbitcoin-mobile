import 'package:electrum/setup.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';

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
