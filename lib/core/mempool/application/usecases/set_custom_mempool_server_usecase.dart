import 'package:bb_mobile/core/mempool/application/dtos/requests/set_custom_mempool_server_request.dart';
import 'package:bb_mobile/core/mempool/domain/entities/mempool_server.dart';
import 'package:bb_mobile/core/mempool/domain/errors/mempool_server_exception.dart';
import 'package:bb_mobile/core/mempool/domain/ports/mempool_server_validator_port.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_server_repository.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/normalized_mempool_url.dart';
import 'package:bb_mobile/core/mempool/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';

enum SetCustomMempoolServerError {
  sameAsDefault,
  validationFailed,
  saveFailed,
  unexpected,
}

class SetCustomMempoolServerResult {
  final bool isValid;
  final SetCustomMempoolServerError? errorType;
  final MempoolValidationErrorType? validationErrorType;

  SetCustomMempoolServerResult({
    required this.isValid,
    this.errorType,
    this.validationErrorType,
  });

  factory SetCustomMempoolServerResult.success() {
    return SetCustomMempoolServerResult(isValid: true);
  }

  factory SetCustomMempoolServerResult.failure(
    SetCustomMempoolServerError errorType, {
    MempoolValidationErrorType? validationErrorType,
  }) {
    return SetCustomMempoolServerResult(
      isValid: false,
      errorType: errorType,
      validationErrorType: validationErrorType,
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

    final customUrl = NormalizedMempoolUrl(
      request.url,
      enableSsl: request.enableSsl,
    );

    final defaultServerResult = await _fetchDefaultServerSafely(network);
    if (defaultServerResult != null) {
      final defaultUrl = NormalizedMempoolUrl(
        defaultServerResult.url,
        enableSsl: defaultServerResult.enableSsl,
      );
      if (customUrl == defaultUrl) {
        return SetCustomMempoolServerResult.failure(
          SetCustomMempoolServerError.sameAsDefault,
        );
      }
    }

    if (!skipValidation) {
      try {
        final isValid = await _validator.validateServer(
          url: request.url,
          network: network,
          enableSsl: request.enableSsl,
        );

        if (!isValid) {
          return SetCustomMempoolServerResult.failure(
            SetCustomMempoolServerError.validationFailed,
          );
        }
      } on MempoolServerValidationException catch (e) {
        return SetCustomMempoolServerResult.failure(
          SetCustomMempoolServerError.validationFailed,
          validationErrorType: e.errorType,
        );
      } catch (e) {
        return SetCustomMempoolServerResult.failure(
          SetCustomMempoolServerError.unexpected,
        );
      }
    }

    try {
      final server = MempoolServer.createCustom(
        url: request.url,
        network: network,
        enableSsl: request.enableSsl,
      );

      await _serverRepository.save(server);

      return SetCustomMempoolServerResult.success();
    } catch (e) {
      log.warning('Failed to save mempool server: $e');
      return SetCustomMempoolServerResult.failure(
        SetCustomMempoolServerError.saveFailed,
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
      log.warning('Could not fetch default mempool server for comparison: $e');
      return null;
    }
  }
}
