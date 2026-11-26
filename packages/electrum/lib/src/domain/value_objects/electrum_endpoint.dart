import '../electrum_server.dart';
import '../electrum_server_network.dart';

/// A configured Electrum endpoint. Its stored URL identifies it within its network.
final class ElectrumEndpoint {
  final String url;
  final ElectrumServerNetwork network;
  final bool isCustom;
  final int priority;

  const ElectrumEndpoint({
    required this.url,
    required this.network,
    required this.isCustom,
    required this.priority,
  });
}

ElectrumEndpoint toElectrumEndpoint(ElectrumServer server) => ElectrumEndpoint(
  url: server.url,
  network: server.network,
  isCustom: server.isCustom,
  priority: server.priority,
);
