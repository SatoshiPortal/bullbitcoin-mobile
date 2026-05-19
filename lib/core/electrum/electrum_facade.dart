import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

class ElectrumServerToUse {
  final String url;
  final bool tls;
  final bool validateDomain;
  final int timeout;

  const ElectrumServerToUse({
    required this.url,
    required this.tls,
    required this.validateDomain,
    required this.timeout,
  });
}

class ElectrumFacade {
  final ElectrumServerRepository _electrumServerRepository;
  final ElectrumSettingsRepository _electrumSettingsRepository;

  ElectrumFacade({
    required ElectrumServerRepository electrumServerRepository,
    required ElectrumSettingsRepository electrumSettingsRepository,
  }) : _electrumServerRepository = electrumServerRepository,
       _electrumSettingsRepository = electrumSettingsRepository;

  Future<ElectrumServerToUse?> getPreferredServer({
    required bool isTestnet,
    required bool isLiquid,
  }) async {
    final network = ElectrumServerNetwork.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: isLiquid,
    );
    final (servers, settings) =
        await (
          _electrumServerRepository.fetchAll(
            isTestnet: network.isTestnet,
            isLiquid: network.isLiquid,
          ),
          _electrumSettingsRepository.fetchByNetwork(network),
        ).wait;

    final customServers = servers.where((s) => s.isCustom).toList();
    final candidates = customServers.isNotEmpty ? customServers : servers;
    if (candidates.isEmpty) {
      return null;
    }
    candidates.sort((a, b) => a.priority.compareTo(b.priority));
    final server = candidates.first;

    return ElectrumServerToUse(
      url: server.url,
      tls: true,
      validateDomain: settings.validateDomain,
      timeout: settings.timeout,
    );
  }
}
