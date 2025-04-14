import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart' show Network;

class CheckElectrumStatusUsecase {
  final ElectrumServerRepository _electrumServerRepository;
  CheckElectrumStatusUsecase({
    required ElectrumServerRepository electrumServerRepository,
  }) : _electrumServerRepository = electrumServerRepository;
  Future<ElectrumServerStatus> execute({
    required ElectrumServerProvider provider,
    required Network network,
  }) async {
    final server = await _electrumServerRepository.getElectrumServer(
      provider: provider,
      network: network,
    );
    return server.status;
  }
}
