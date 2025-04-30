import 'package:bb_mobile/core/electrum/data/repository/electrum_server_repository_impl.dart';
import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class GetBestAvailableServerUsecase {
  final ElectrumServerRepository electrumServerRepository;

  const GetBestAvailableServerUsecase({required this.electrumServerRepository});

  Future<ElectrumServer> execute({
    required Network network,
    bool checkStatus = true,
  }) async {
    return await electrumServerRepository.getPrioritizedServer(
      network: network,
      checkStatus: checkStatus,
    );
  }
}
