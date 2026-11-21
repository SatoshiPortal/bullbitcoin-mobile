import 'package:mempool/src/domain/entities/mempool_server_selection.dart';
import 'package:mempool/src/domain/entities/mempool_server.dart';
import 'package:mempool/src/domain/mempool_failure.dart';
import 'package:mempool/src/domain/repositories/mempool_server_repository.dart';
import 'package:mempool/src/domain/value_objects/mempool_server_network.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

class LoadMempoolServerDataUsecase {
  final MempoolServerRepository _serverRepository;

  LoadMempoolServerDataUsecase({required this._serverRepository});

  @useResult
  Future<Result<MempoolServerSelection, MempoolFailure>> execute(
    MempoolServerNetwork network,
  ) async {
    final (defaultResult, customResult) = await (
      _serverRepository.fetchDefaultServer(network),
      _serverRepository.fetchCustomServer(network),
    ).wait;

    final MempoolServer defaultServer;
    switch (defaultResult) {
      case Ok(:final value):
        defaultServer = value;
      case Err(:final failure):
        return Err(failure);
    }
    final MempoolServer? customServer;
    switch (customResult) {
      case Ok(:final value):
        customServer = value;
      case Err(:final failure):
        return Err(failure);
    }
    return Ok(
      MempoolServerSelection(
        defaultServer: defaultServer,
        customServer: customServer,
      ),
    );
  }
}
