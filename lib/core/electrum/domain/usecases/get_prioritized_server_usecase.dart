import 'package:bb_mobile/core/electrum/data/repository/electrum_server_repository_impl.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server_provider.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class GetPrioritizedServerUsecase {
  final ElectrumServerRepository electrumServerRepository;

  const GetPrioritizedServerUsecase({required this.electrumServerRepository});

  Future<ElectrumServer> execute({required Network network}) async {
    final prioritizedServer = await electrumServerRepository
        .getPrioritizedServer(network: network);

    // First check the prioritized server
    final serverStatus = await electrumServerRepository.checkServerConnectivity(
      url: prioritizedServer.url,
    );

    if (serverStatus == ElectrumServerStatus.online) {
      return prioritizedServer.copyWith(status: ElectrumServerStatus.online);
    }

    // If prioritized server is offline and custom, return it as offline
    if (prioritizedServer.electrumServerProvider ==
        const ElectrumServerProvider.customProvider()) {
      return prioritizedServer.copyWith(status: ElectrumServerStatus.offline);
    }

    // Try alternative default servers
    final defaultServers = await electrumServerRepository.getDefaultServers(
      network: network,
    );

    for (final server in defaultServers) {
      final status = await electrumServerRepository.checkServerConnectivity(
        url: server.url,
      );
      if (status == ElectrumServerStatus.online) {
        return server.copyWith(status: ElectrumServerStatus.online);
      }
    }

    // If all servers are offline, return the prioritized one as offline
    return prioritizedServer.copyWith(status: ElectrumServerStatus.offline);
  }
}
