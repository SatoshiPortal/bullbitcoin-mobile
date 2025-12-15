import 'package:bb_mobile/core_deprecated/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core_deprecated/tor/domain/ports/tor_config_port.dart';
import 'package:bb_mobile/core_deprecated/tor/domain/value_objects/tor_proxy_config.dart';

class TorConfigAdapter implements TorConfigPort {
  final SettingsRepository _settingsRepository;

  TorConfigAdapter({required SettingsRepository settingsRepository})
    : _settingsRepository = settingsRepository;

  @override
  Future<TorProxyConfig?> getExternalTorConfig() async {
    final settings = await _settingsRepository.fetch();

    if (settings.useTorProxy) {
      return TorProxyConfig(port: settings.torProxyPort);
    }

    return null;
  }
}
