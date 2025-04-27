import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';

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

  /// Gets the best server for a network based on status and priority
  Future<ElectrumServer> getPreferredServer({
    required Network network,
    bool checkStatus = true,
  });
}
