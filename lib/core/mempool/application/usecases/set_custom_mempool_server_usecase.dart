import 'package:bb_mobile/core/mempool/application/dtos/requests/set_custom_mempool_server_request.dart';
import 'package:bb_mobile/core/mempool/domain/entities/mempool_server.dart';
import 'package:bb_mobile/core/mempool/domain/errors/mempool_failure.dart';
import 'package:bb_mobile/core/mempool/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/mempool/domain/ports/mempool_server_validator_port.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_server_repository.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/normalized_mempool_url.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

class SetCustomMempoolServerUsecase {
  final MempoolServerRepository _serverRepository;
  final MempoolServerValidatorPort _validator;
  final MempoolEnvironmentPort _environmentPort;

  SetCustomMempoolServerUsecase({
    required this._serverRepository,
    required this._validator,
    required this._environmentPort,
  });

  @useResult
  Future<Result<void, MempoolFailure>> execute(
    SetCustomMempoolServerRequest request, {
    bool skipValidation = false,
  }) async {
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

    final MempoolServer server;
    switch (MempoolServer.tryCreateCustom(
      url: request.url,
      network: network,
      enableSsl: request.enableSsl,
    )) {
      case Ok(:final value):
        server = value;
      case Err(:final failure):
        return Err(failure);
    }

    // Compare against the default server. A failure fetching the default is
    // non-fatal here — just skip the comparison.
    final customUrl = NormalizedMempoolUrl(
      request.url,
      enableSsl: request.enableSsl,
    );
    final defaultServer = (await _serverRepository.fetchDefaultServer(
      network,
    )).fold((s) => s, (_) => null);
    if (defaultServer != null) {
      final defaultUrl = NormalizedMempoolUrl(
        defaultServer.url,
        enableSsl: defaultServer.enableSsl,
      );
      if (customUrl == defaultUrl) {
        return const Err(MempoolServerSameAsDefaultFailure());
      }
    }

    if (!skipValidation) {
      final validation = await _validator.validateServer(
        url: request.url,
        network: network,
        enableSsl: request.enableSsl,
      );
      if (validation case Err(:final failure)) {
        return Err(failure);
      }
    }

    return _serverRepository.save(server);
  }
}
