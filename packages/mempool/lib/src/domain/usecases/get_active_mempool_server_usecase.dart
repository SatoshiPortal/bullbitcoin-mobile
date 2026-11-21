import 'package:mempool/src/domain/entities/mempool_server.dart';
import 'package:mempool/src/domain/mempool_failure.dart';
import 'package:mempool/src/domain/repositories/mempool_server_repository.dart';
import 'package:mempool/src/domain/value_objects/mempool_server_network.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

class GetActiveMempoolServerUsecase {
  final MempoolServerRepository _serverRepository;

  GetActiveMempoolServerUsecase({required this._serverRepository});

  @useResult
  Future<Result<MempoolServer, MempoolFailure>> execute({
    required bool isTestnet,
    required bool isLiquid,
  }) async {
    final network = MempoolServerNetwork.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: isLiquid,
    );

    final customResult = await _serverRepository.fetchCustomServer(network);
    if (customResult case Ok(:final value) when value != null) {
      return Ok(value);
    }
    if (customResult case Err(:final failure)) {
      return Err(failure);
    }

    return _serverRepository.fetchDefaultServer(network);
  }
}
