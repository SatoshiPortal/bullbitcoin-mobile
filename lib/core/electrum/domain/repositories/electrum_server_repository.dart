import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

abstract class ElectrumServerRepository {
  Future<void> save(ElectrumServer server);
  Future<void> batchSave(List<ElectrumServer> servers);
  Future<List<ElectrumServer>> fetchAll({
    bool? isTestnet,
    bool? isLiquid,
    bool? isCustom,
  });
  Future<ElectrumServer?> fetchByUrl(String url);
  Future<List<ElectrumServer>> fetchCustomServers({
    required ElectrumServerNetwork network,
  });
  Future<List<ElectrumServer>> fetchDefaultServers({
    required ElectrumServerNetwork network,
  });
  Future<void> delete({required String url});
}
