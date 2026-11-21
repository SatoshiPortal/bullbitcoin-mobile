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
  Future<Result<MempoolServer, MempoolFailure>> execute(Network network) async {
    final supported = MempoolServerNetwork.fromNetwork(network);
    if (supported == null) {
      return Err(MempoolUnsupportedNetworkFailure(network));
    }

    final customResult = await _serverRepository.fetchCustomServer(supported);
    if (customResult case Ok(:final value) when value != null) {
      return Ok(value);
    }
    if (customResult case Err(:final failure)) {
      return Err(failure);
    }

    return _serverRepository.fetchDefaultServer(supported);
  }
}
