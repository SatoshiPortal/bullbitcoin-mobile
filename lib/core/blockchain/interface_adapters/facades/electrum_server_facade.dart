import 'package:bb_mobile/core/blockchain/domain/electrum_server.dart';
import 'package:bb_mobile/core/blockchain/domain/ports/electrum_server_port.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/get_electrum_servers_to_broadcast_request.dart';
import 'package:bb_mobile/core/electrum/application/usecases/get_electrum_servers_to_broadcast_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

class ElectrumServerFacade implements ElectrumServerPort {
  final GetElectrumServersToBroadcastUsecase
  _getElectrumServersToBroadcastUsecase;

  ElectrumServerFacade({
    required GetElectrumServersToBroadcastUsecase
    getElectrumServersToBroadcastUsecase,
  }) : _getElectrumServersToBroadcastUsecase =
           getElectrumServersToBroadcastUsecase;

  @override
  Future<List<ElectrumServer>> getElectrumServers({
    required bool isTestnet,
    required bool isLiquid,
  }) async {
    final network = ElectrumServerNetwork.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: isLiquid,
    );
    final request = GetElectrumServersToBroadcastRequest(network: network);
    final serversAndSetting = await _getElectrumServersToBroadcastUsecase
        .execute(request);
    final settings = serversAndSetting.settings;
    final servers =
        serversAndSetting.servers
            .map(
              (e) => ElectrumServer(
                url: e.url,
                priority: e.priority,
                retry: settings.retry,
                timeout: settings.timeout,
                stopGap: settings.stopGap,
                validateDomain: settings.validateDomain,
                socks5: settings.socks5,
                isCustom: e.isCustom,
              ),
            )
            .toList();
    return servers;
  }
}
