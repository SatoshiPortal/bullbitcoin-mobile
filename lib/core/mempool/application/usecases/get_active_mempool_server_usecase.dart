import 'package:bb_mobile/core/mempool/domain/entities/mempool_server.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_server_repository.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';

class GetActiveMempoolServerUsecase {
  final MempoolServerRepository _serverRepository;

  GetActiveMempoolServerUsecase({
    required MempoolServerRepository serverRepository,
  }) : _serverRepository = serverRepository;

  Future<MempoolServer> execute({
    required bool isTestnet,
    required bool isLiquid,
  }) async {
    final network = MempoolServerNetwork.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: isLiquid,
    );

    // custom server is given priority over default
    final customServer = await _serverRepository.fetchCustomServer(network);
    if (customServer != null) {
      return customServer;
    }

    return _serverRepository.fetchDefaultServer(network);
  }
}
