import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

class ElectrumServersAdapter implements ElectrumServersPort {
  final ElectrumServerRepository _repository;

  ElectrumServersAdapter({required ElectrumServerRepository repository})
    : _repository = repository;

  @override
  Future<List<ElectrumServer>> getServersToUse({
    required ElectrumServerNetwork network,
  }) {
    return _repository.fetchActiveServers(network: network);
  }
}
