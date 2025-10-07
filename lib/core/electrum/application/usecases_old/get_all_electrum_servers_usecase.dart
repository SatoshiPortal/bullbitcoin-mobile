import 'package:bb_mobile/core/electrum/data/repository/electrum_server_repository_impl.dart';
import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class GetAllElectrumServersUsecase {
  final ElectrumServerRepository _electrumServerRepository;

  GetAllElectrumServersUsecase({
    required ElectrumServerRepository electrumServerRepository,
  }) : _electrumServerRepository = electrumServerRepository;

  Future<List<ElectrumServer>> execute({required Network network}) async {
    try {
      return await _electrumServerRepository.getElectrumServers(
        network: network,
      );
    } catch (e) {
      rethrow;
    }
  }
}
