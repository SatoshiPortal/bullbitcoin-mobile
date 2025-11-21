import 'package:bb_mobile/core/blockchain/domain/ports/electrum_server_port.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/get_electrum_servers_to_use_request.dart';
import 'package:bb_mobile/core/electrum/application/usecases/get_electrum_servers_to_use_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

class ElectrumServerAdapter implements ElectrumServerPort {
  final GetElectrumServersToUseUsecase _getElectrumServersToUseUsecase;

  ElectrumServerAdapter({
    required GetElectrumServersToUseUsecase getElectrumServersToUseUsecase,
  }) : _getElectrumServersToUseUsecase = getElectrumServersToUseUsecase;

  @override
  Future<List<ElectrumServer>> getElectrumServers({
    required bool isTestnet,
    required bool isLiquid,
  }) async {
    final network = ElectrumServerNetwork.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: isLiquid,
    );
    final request = GetElectrumServersToUseRequest(network: network);
    final serversAndSetting = await _getElectrumServersToUseUsecase.execute(
      request,
    );
    final settings = serversAndSetting.settings;

    String? socks5Url = settings.socks5;
    if (settings.useTorProxy && socks5Url == null) {
      // Only use Tor proxy for Bitcoin mainnet/testnet, not Liquid
      if (!isLiquid) {
        socks5Url = '127.0.0.1:${settings.torProxyPort}';
      }
    }

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
                socks5: socks5Url,
                isCustom: e.isCustom,
              ),
            )
            .toList();
    return servers;
  }
}
