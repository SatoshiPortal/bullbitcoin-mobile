import 'package:electrum/setup.dart';
import 'package:primitives/primitives.dart' show NetworkEnv;
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';

class EnvironmentAdapter {
  final SettingsRepository Function() _settingsRepository;

  EnvironmentAdapter({required this._settingsRepository});

  Future<NetworkEnv> readNetwork() async =>
      (await _settingsRepository().fetch()).environment.networkEnv;

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
