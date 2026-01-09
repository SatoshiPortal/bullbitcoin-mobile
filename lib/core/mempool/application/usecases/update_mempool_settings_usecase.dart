import 'package:bb_mobile/core/mempool/application/dtos/requests/update_mempool_settings_request.dart';
import 'package:bb_mobile/core/mempool/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_settings_repository.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';

class UpdateMempoolSettingsUsecase {
  final MempoolSettingsRepository _settingsRepository;
  final MempoolEnvironmentPort _environmentPort;

  UpdateMempoolSettingsUsecase({
    required MempoolSettingsRepository settingsRepository,
    required MempoolEnvironmentPort environmentPort,
  }) : _settingsRepository = settingsRepository,
       _environmentPort = environmentPort;

  Future<void> execute(UpdateMempoolSettingsRequest request) async {
    final environment = await _environmentPort.getEnvironment();
    final isTestnet = environment == Environment.testnet;

    final network = MempoolServerNetwork.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: request.isLiquid,
    );

    final currentSettings = await _settingsRepository.fetchByNetwork(network);

    final updatedSettings = currentSettings.updateUseForFeeEstimation(
      request.useForFeeEstimation,
    );

    await _settingsRepository.save(updatedSettings);
  }
}
