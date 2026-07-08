import 'package:bb_mobile/core/mempool/domain/entities/mempool_server.dart';
import 'package:bb_mobile/core/mempool/domain/errors/mempool_failure.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_server_repository.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/utils/result.dart';
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
