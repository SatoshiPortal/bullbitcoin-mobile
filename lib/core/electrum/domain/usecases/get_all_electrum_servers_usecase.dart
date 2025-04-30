import 'package:bb_mobile/core/electrum/data/repository/electrum_server_repository_impl.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class GetAllElectrumServersUsecase {
  final ElectrumServerRepository _electrumServerRepository;

  GetAllElectrumServersUsecase({
    required ElectrumServerRepository electrumServerRepository,
  }) : _electrumServerRepository = electrumServerRepository;

  Future<List<ElectrumServer>> execute({
    required bool checkStatus,
    required Network network,
  }) async {
    return await _electrumServerRepository.getElectrumServers(
      checkStatus: checkStatus,
      network: network,
    );
  }
}
