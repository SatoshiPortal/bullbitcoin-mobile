import 'package:bb_mobile/core/mempool/application/dtos/requests/delete_custom_mempool_server_request.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_server_repository.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/mempool/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';

class DeleteCustomMempoolServerUsecase {
  final MempoolServerRepository _serverRepository;
  final MempoolEnvironmentPort _environmentPort;

  DeleteCustomMempoolServerUsecase({
    required MempoolServerRepository serverRepository,
    required MempoolEnvironmentPort environmentPort,
  }) : _serverRepository = serverRepository,
       _environmentPort = environmentPort;

  Future<void> execute(DeleteCustomMempoolServerRequest request) async {
    final environment = await _environmentPort.getEnvironment();
    final isTestnet = environment == Environment.testnet;

    final network = MempoolServerNetwork.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: request.isLiquid,
    );

    await _serverRepository.deleteCustomServer(network);
  }
}
