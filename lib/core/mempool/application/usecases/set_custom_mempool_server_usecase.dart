import 'package:bb_mobile/core/mempool/application/dtos/requests/set_custom_mempool_server_request.dart';
import 'package:bb_mobile/core/mempool/domain/entities/mempool_server.dart';
import 'package:bb_mobile/core/mempool/domain/ports/mempool_server_validator_port.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_server_repository.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/normalized_mempool_url.dart';
import 'package:bb_mobile/core/mempool/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class SetCustomMempoolServerResult {
  final bool isValid;
  final String? errorMessage;

  SetCustomMempoolServerResult({required this.isValid, this.errorMessage});

  factory SetCustomMempoolServerResult.success() {
    return SetCustomMempoolServerResult(isValid: true);
  }

  factory SetCustomMempoolServerResult.failure(String errorMessage) {
    return SetCustomMempoolServerResult(
      isValid: false,
      errorMessage: errorMessage,
    );
  }
}

class SetCustomMempoolServerUsecase {
  final MempoolServerRepository _serverRepository;
  final MempoolServerValidatorPort _validator;
  final MempoolEnvironmentPort _environmentPort;

  SetCustomMempoolServerUsecase({
    required MempoolServerRepository serverRepository,
    required MempoolServerValidatorPort validator,
    required MempoolEnvironmentPort environmentPort,
  }) : _serverRepository = serverRepository,
       _validator = validator,
       _environmentPort = environmentPort;

  Future<SetCustomMempoolServerResult> execute(
    SetCustomMempoolServerRequest request, {
    bool skipValidation = false,
  }) async {
    final environment = await _environmentPort.getEnvironment();
    final isTestnet = environment == Environment.testnet;

    final network = MempoolServerNetwork.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: request.isLiquid,
    );

    final customUrl = NormalizedMempoolUrl(request.url);

    final defaultServerResult = await _fetchDefaultServerSafely(network);
    if (defaultServerResult != null) {
      final defaultUrl = NormalizedMempoolUrl(defaultServerResult.url);
      if (customUrl == defaultUrl) {
        return SetCustomMempoolServerResult.failure(
          'This URL is the same as the default server. Please use a different URL.',
        );
      }
    }

    if (!skipValidation) {
      try {
        final isValid = await _validator.validateServer(
          url: request.url,
          network: network,
        );

        if (!isValid) {
          return SetCustomMempoolServerResult.failure(
            'Server validation failed: Unable to connect or invalid response',
          );
        }
      } catch (e) {
        return SetCustomMempoolServerResult.failure(
          'Validation error: ${e.toString()}',
        );
      }
    }

    try {
      final server = MempoolServer.createCustom(
        url: request.url,
        network: network,
      );

      await _serverRepository.save(server);

      return SetCustomMempoolServerResult.success();
    } catch (e) {
      return SetCustomMempoolServerResult.failure(
        'Failed to save server: ${e.toString()}',
      );
    }
  }

  Future<MempoolServer?> _fetchDefaultServerSafely(
    MempoolServerNetwork network,
  ) async {
    try {
      return await _serverRepository.fetchDefaultServer(network);
    } catch (e) {
      // log the error for debugging but don't throw.
      log.warning(
        'Could not fetch default mempool server for comparison: $e',
      );
      return null;
    }
  }
}
