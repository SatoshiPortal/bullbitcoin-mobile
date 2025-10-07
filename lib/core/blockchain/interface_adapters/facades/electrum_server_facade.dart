import 'package:bb_mobile/core/blockchain/domain/electrum_server.dart';
import 'package:bb_mobile/core/blockchain/domain/ports/electrum_server_port.dart';
import 'package:bb_mobile/core/electrum/application/dtos/responses/get_electrum_servers_and_setting_by_network_response.dart';
import 'package:bb_mobile/core/electrum/application/usecases/get_electrum_servers_and_settings_by_network_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

class ElectrumServerFacade implements ElectrumServerPort {
  final GetElectrumServersAndSettingsByNetworkUsecase
  _getElectrumServersAndSettingByNetworkUsecase;

  ElectrumServerFacade({
    required GetElectrumServersAndSettingsByNetworkUsecase
    getElectrumServersAndSettingByNetworkUsecase,
  }) : _getElectrumServersAndSettingByNetworkUsecase =
           getElectrumServersAndSettingByNetworkUsecase;

  @override
  Future<List<ElectrumServer>> getElectrumServers({
    required bool isTestnet,
    required bool isLiquid,
  }) async {
    final network = ElectrumServerNetwork.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: isLiquid,
    );
    final serversAndSetting =
        await _getElectrumServersAndSettingByNetworkUsecase.execute(network);
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
