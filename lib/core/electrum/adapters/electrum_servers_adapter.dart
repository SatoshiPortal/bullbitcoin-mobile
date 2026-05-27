import 'package:bb_mobile/core/electrum/domain/electrum_fallback_runner.dart';
import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

class ElectrumServersAdapter implements ElectrumServersPort {
  final ElectrumServerRepository _repository;

  ElectrumServersAdapter({required ElectrumServerRepository repository})
    : _repository = repository;

  @override
  Future<T> runWithFallback<T>({
    required ElectrumServerNetwork network,
    required Future<T> Function(ElectrumServer server) operation,
    bool Function(Object error)? isTransient,
  }) async {
    // Resolve the active set exactly once. This is what guarantees the
    // privacy rule: when a custom server is set this list contains only
    // custom servers, so the loop can never reach a default.
    final servers = await _repository.fetchActiveServers(network: network);
    if (servers.isEmpty) {
      throw NoElectrumServersConfiguredException(network);
    }

    return runElectrumFallback<ElectrumServer, T>(
      servers: servers,
      urlOf: (server) => server.url,
      isCustomOf: (server) => server.isCustom,
      operation: operation,
      isTransient: isTransient,
    );
  }
}
