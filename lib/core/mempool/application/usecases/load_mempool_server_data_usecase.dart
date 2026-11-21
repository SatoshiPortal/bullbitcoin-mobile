import 'package:bb_mobile/core/mempool/application/dtos/mempool_server_dto.dart';
import 'package:bb_mobile/core/mempool/application/dtos/requests/load_mempool_server_data_request.dart';
import 'package:bb_mobile/core/mempool/application/dtos/responses/load_mempool_server_data_response.dart';
import 'package:bb_mobile/core/mempool/domain/entities/mempool_server.dart';
import 'package:bb_mobile/core/mempool/domain/errors/mempool_failure.dart';
import 'package:bb_mobile/core/mempool/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_server_repository.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

class LoadMempoolServerDataUsecase {
  final MempoolServerRepository _serverRepository;
  final MempoolEnvironmentPort _environmentPort;

  LoadMempoolServerDataUsecase({
    required this._serverRepository,
    required this._environmentPort,
  });

  @useResult
  Future<Result<LoadMempoolServerDataResponse, MempoolFailure>> execute(
    LoadMempoolServerDataRequest request,
  ) async {
    final BitcoinNetwork environment;
    switch (await _environmentPort.getEnvironment()) {
      case Ok(:final value):
        environment = value;
      case Err(:final failure):
        return Err(failure);
    }
    final isTestnet = environment == BitcoinNetwork.testnet;

    final network = MempoolServerNetwork.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: request.isLiquid,
    );

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
      LoadMempoolServerDataResponse(
        defaultServer: MempoolServerDto.fromEntity(defaultServer),
        customServer: customServer != null
            ? MempoolServerDto.fromEntity(customServer)
            : null,
      ),
    );
  }
}
