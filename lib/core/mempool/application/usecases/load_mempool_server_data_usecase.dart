import 'package:bb_mobile/core/mempool/application/dtos/mempool_server_dto.dart';
import 'package:bb_mobile/core/mempool/application/dtos/mempool_settings_dto.dart';
import 'package:bb_mobile/core/mempool/application/dtos/requests/load_mempool_server_data_request.dart';
import 'package:bb_mobile/core/mempool/application/dtos/responses/load_mempool_server_data_response.dart';
import 'package:bb_mobile/core/mempool/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_server_repository.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_settings_repository.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';

class LoadMempoolServerDataUsecase {
  final MempoolServerRepository _serverRepository;
  final MempoolSettingsRepository _settingsRepository;
  final MempoolEnvironmentPort _environmentPort;

  LoadMempoolServerDataUsecase({
    required MempoolServerRepository serverRepository,
    required MempoolSettingsRepository settingsRepository,
    required MempoolEnvironmentPort environmentPort,
  }) : _serverRepository = serverRepository,
       _settingsRepository = settingsRepository,
       _environmentPort = environmentPort;

  Future<LoadMempoolServerDataResponse> execute(
    LoadMempoolServerDataRequest request,
  ) async {
    final environment = await _environmentPort.getEnvironment();
    final isTestnet = environment == Environment.testnet;

    final network = MempoolServerNetwork.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: request.isLiquid,
    );

    final (defaultServer, customServer, settings) = await (
      _serverRepository.fetchDefaultServer(network),
      _serverRepository.fetchCustomServer(network),
      _settingsRepository.fetchByNetwork(network),
    ).wait;

    return LoadMempoolServerDataResponse(
      defaultServer: MempoolServerDto.fromEntity(defaultServer),
      customServer: customServer != null
          ? MempoolServerDto.fromEntity(customServer)
          : null,
      settings: MempoolSettingsDto.fromEntity(settings),
    );
  }
}
