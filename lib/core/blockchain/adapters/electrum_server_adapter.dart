import 'package:bb_mobile/core/blockchain/domain/ports/electrum_server_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class ElectrumServerAdapter implements ElectrumServerPort {
  final ElectrumServerRepository _electrumServerRepository;
  final ElectrumSettingsRepository _electrumSettingsRepository;
  final SettingsRepository _settingsRepository;

  ElectrumServerAdapter({
    required ElectrumServerRepository electrumServerRepository,
    required ElectrumSettingsRepository electrumSettingsRepository,
    required SettingsRepository settingsRepository,
  }) : _electrumServerRepository = electrumServerRepository,
       _electrumSettingsRepository = electrumSettingsRepository,
       _settingsRepository = settingsRepository;

  @override
  Future<List<ElectrumServer>> getElectrumServers({
    required bool isTestnet,
    required bool isLiquid,
  }) async {
    final network = ElectrumServerNetwork.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: isLiquid,
    );

    final (activeServers, settings, appSettings) = await (
      _electrumServerRepository.fetchActiveServers(network: network),
      _electrumSettingsRepository.fetchByNetwork(network),
      _settingsRepository.fetch(),
    ).wait;

    // Tor proxy applies to Bitcoin only, never Liquid.
    final socks5Url = (appSettings.useTorProxy && !isLiquid)
        ? (settings.socks5 ?? '127.0.0.1:${appSettings.torProxyPort}')
        : settings.socks5;

    return activeServers
        .map(
          (e) => ElectrumServer(
            url: e.url,
            priority: e.priority,
            retry: settings.retry,
            timeout: settings.timeout,
            stopGap: settings.stopGap,
            validateDomain: settings.validateDomain,
            socks5: socks5Url,
            isCustom: e.isCustom,
          ),
        )
        .toList();
  }
}
