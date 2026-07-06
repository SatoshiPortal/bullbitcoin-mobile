import 'package:bb_mobile/core/mempool/application/dtos/requests/delete_custom_mempool_server_request.dart';
import 'package:bb_mobile/core/mempool/domain/errors/mempool_failure.dart';
import 'package:bb_mobile/core/mempool/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_server_repository.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

class DeleteCustomMempoolServerUsecase {
  final MempoolServerRepository _serverRepository;
  final MempoolEnvironmentPort _environmentPort;

  DeleteCustomMempoolServerUsecase({
    required this._serverRepository,
    required this._environmentPort,
  });

  @useResult
  Future<Result<void, MempoolFailure>> execute(
    DeleteCustomMempoolServerRequest request,
  ) async {
    final Environment environment;
    switch (await _environmentPort.getEnvironment()) {
      case Ok(:final value):
        environment = value;
      case Err(:final failure):
        return Err(failure);
    }
    final isTestnet = environment == Environment.testnet;

    final network = MempoolServerNetwork.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: request.isLiquid,
    );

    return _serverRepository.deleteCustomServer(network);
  }
}
