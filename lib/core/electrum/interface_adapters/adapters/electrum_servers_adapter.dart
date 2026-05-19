import 'package:bb_mobile/core/electrum/application/dtos/requests/get_electrum_servers_to_use_request.dart';
import 'package:bb_mobile/core/electrum/application/usecases/get_electrum_servers_to_use_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

class ElectrumServersAdapter implements ElectrumServersPort {
  final GetElectrumServersToUseUsecase _getServersUsecase;

  ElectrumServersAdapter({
    required GetElectrumServersToUseUsecase getServersUsecase,
  }) : _getServersUsecase = getServersUsecase;

  @override
  Future<List<ElectrumServer>> getServersToUse({
    required ElectrumServerNetwork network,
  }) async {
    final response = await _getServersUsecase.execute(
      GetElectrumServersToUseRequest(network: network),
    );
    return response.servers
        .map(
          (dto) => ElectrumServer.existing(
            url: dto.url,
            network: dto.network,
            isCustom: dto.isCustom,
            priority: dto.priority,
          ),
        )
        .toList();
  }
}
