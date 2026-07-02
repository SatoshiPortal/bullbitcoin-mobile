import 'package:bb_mobile/core/mempool/application/dtos/requests/update_mempool_settings_request.dart';
import 'package:bb_mobile/core/mempool/domain/entities/mempool_settings.dart';
import 'package:bb_mobile/core/mempool/domain/errors/mempool_failure.dart';
import 'package:bb_mobile/core/mempool/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_settings_repository.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

class UpdateMempoolSettingsUsecase {
  final MempoolSettingsRepository _settingsRepository;
  final MempoolEnvironmentPort _environmentPort;

  UpdateMempoolSettingsUsecase({
    required this._settingsRepository,
    required this._environmentPort,
  });

  @useResult
  Future<Result<void, MempoolFailure>> execute(
    UpdateMempoolSettingsRequest request,
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

    final MempoolSettings currentSettings;
    switch (await _settingsRepository.fetchByNetwork(network)) {
      case Ok(:final value):
        currentSettings = value;
      case Err(:final failure):
        return Err(failure);
    }

    final updatedSettings = currentSettings.updateUseForFeeEstimation(
      request.useForFeeEstimation,
    );

    return _settingsRepository.save(updatedSettings);
  }
}
