import 'package:electrum/src/domain/repositories/electrum_server_repository.dart';
import 'package:electrum/src/domain/electrum_server_network.dart';
import 'package:electrum/src/domain/value_objects/electrum_server_url.dart';
import 'package:electrum/src/domain/ports/environment_port.dart';

final class HasActiveCustomBitcoinOnionServerUsecase {
  final ElectrumServerRepository _serverRepository;
  final EnvironmentPort _environment;

  const HasActiveCustomBitcoinOnionServerUsecase(
    this._serverRepository,
    this._environment,
  );

  Future<bool> execute() async {
    try {
      final result = await _serverRepository.fetchActiveServers(
        network: ElectrumServerNetwork.fromEnvironment(
          environment: await _environment.getEnvironment(),
          isLiquid: false,
        ),
      );
      return result.fold<bool>(
        (servers) => servers.any(
          (server) => server.isCustom && ElectrumServerUrl(server.url).isOnion,
        ),
        (_) => false,
      );
    } on Exception {
      return false;
    }
  }
}
