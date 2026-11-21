import 'package:mempool/src/domain/entities/mempool_server.dart';
import 'package:mempool/src/domain/mempool_failure.dart';
import 'package:mempool/src/domain/ports/mempool_server_validator_port.dart';
import 'package:mempool/src/domain/repositories/mempool_server_repository.dart';
import 'package:mempool/src/domain/value_objects/mempool_server_network.dart';
import 'package:mempool/src/domain/value_objects/normalized_mempool_url.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

class SetCustomMempoolServerUsecase {
  final MempoolServerRepository _serverRepository;
  final MempoolServerValidatorPort _validator;

  SetCustomMempoolServerUsecase({
    required this._serverRepository,
    required this._validator,
  });

  @useResult
  Future<Result<void, MempoolFailure>> execute(
    MempoolServer server, {
    required MempoolServerNetwork network,
  }) async {
    if (!server.isCustom) {
      return const Err(MempoolServerSameAsDefaultFailure());
    }

    // Compare against the default server. A failure fetching the default is
    // non-fatal here — just skip the comparison.
    final customUrl = NormalizedMempoolUrl.fromNormalized(
      server.url,
      enableSsl: server.enableSsl,
    );
    final defaultServer = (await _serverRepository.fetchDefaultServer(network))
        .fold((s) => s, (_) => null);
    if (defaultServer != null) {
      final defaultUrl = NormalizedMempoolUrl(
        defaultServer.url,
        enableSsl: defaultServer.enableSsl,
      );
      if (customUrl == defaultUrl) {
        return const Err(MempoolServerSameAsDefaultFailure());
      }
    }

    final validation = await _validator.validateServer(
      url: server.fullUrl,
      network: network,
      enableSsl: server.enableSsl,
    );
    if (validation case Err(:final failure)) {
      return Err(failure);
    }

    return _serverRepository.save(server);
  }
}
