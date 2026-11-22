import 'package:electrum/setup.dart';
import 'package:preferences/preferences.dart';

class EnvironmentAdapter {
  final Preferences Function() _settingsRepository;

  EnvironmentAdapter({required this._settingsRepository});

  Future<ElectrumPreferences> readPreferences() async {
    final settings = (await _settingsRepository().fetch()).fold(
      (value) => value,
      (failure) => throw Exception('Preferences read failed'),
    );
    return (
      isSuperuser: settings.isSuperuser,
      isDevModeEnabled: settings.isDevModeEnabled,
      useTorProxy: settings.useTorProxy,
      torProxyPort: settings.torProxyPort,
    );
  }
}
