import 'package:bb_mobile/core/mempool/domain/entities/mempool_server.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_server_repository.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';

class GetActiveMempoolServerUsecase {
  final MempoolServerRepository _serverRepository;

  GetActiveMempoolServerUsecase({
    required this._serverRepository,
  });

  Future<MempoolServer> execute({
    required bool isTestnet,
    required bool isLiquid,
  }) async {
    final network = MempoolServerNetwork.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: isLiquid,
    );

    // This use-case feeds the (throw-based) fees pipeline, not the failure
    // pipeline — so unwrap the repo Results here, surfacing the logged reason.
    final customServer = (await _serverRepository.fetchCustomServer(network))
        .fold(
          (server) => server,
          (failure) => throw Exception(
            failure.logMessage ?? 'Failed to fetch custom mempool server',
          ),
        );
    if (customServer != null) {
      return customServer;
    }

    return (await _serverRepository.fetchDefaultServer(network)).fold(
      (server) => server,
      (failure) => throw Exception(
        failure.logMessage ?? 'Failed to fetch default mempool server',
      ),
    );
  }
}
