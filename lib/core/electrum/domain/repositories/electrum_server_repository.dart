import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

abstract class ElectrumServerRepository {
  Future<void> setElectrumServer(ElectrumServer server);

  /// Gets a default server by preset
  Future<ElectrumServer?> getDefaultServerByProvider({
    required DefaultElectrumServerProvider provider,
    required Network network,
    bool checkStatus = false,
  });

  /// Gets a custom server for a specific network
  Future<ElectrumServer?> getCustomServer({
    required Network network,
    bool checkStatus = false,
  });

  /// Gets all servers for a network
  Future<List<ElectrumServer>> getElectrumServers({
    required Network network,
    required bool checkStatus,
  });
  Future<ElectrumServer> getPrioritizedServer({
    required Network network,
    bool checkStatus = false,
  });
}
