import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/tor/domain/ports/tor_config_port.dart';
import 'package:bb_mobile/core/tor/domain/value_objects/tor_proxy_config.dart';
import 'package:bb_mobile/core/tor/infrastructure/services/tor_connectivity_service.dart';
import 'package:bb_mobile/core/tor/tor_status.dart';

class TorConfigAdapter implements TorConfigPort {
  final SettingsRepository _settingsRepository;
  final TorConnectivityService _torConnectivityService;

  TorConfigAdapter({
    required SettingsRepository settingsRepository,
    required TorConnectivityService torConnectivityService,
  }) : _settingsRepository = settingsRepository,
       _torConnectivityService = torConnectivityService;

  @override
  Future<TorProxyConfig?> getAvailableExternalTorConfig() async {
    final settings = await _settingsRepository.fetch();

    final status = await _torConnectivityService.checkConnection(
      settings.torProxyPort,
    );

    if (status == TorStatus.online) {
      return TorProxyConfig(port: settings.torProxyPort);
    }

    return null;
  }
}
