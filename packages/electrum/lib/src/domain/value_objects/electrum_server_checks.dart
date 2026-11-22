import 'electrum_endpoint.dart';
import 'electrum_options.dart';
import 'electrum_server_status.dart';

/// The configured endpoints and their latest statuses during one refresh.
final class ElectrumServerChecks {
  final List<ElectrumEndpoint> servers;
  final Map<String, ElectrumServerStatus> serverStatuses;
  final ElectrumOptions settings;

  ElectrumServerChecks({
    required List<ElectrumEndpoint> servers,
    required Map<String, ElectrumServerStatus> serverStatuses,
    required this.settings,
  }) : servers = List.unmodifiable(servers),
       serverStatuses = Map.unmodifiable(serverStatuses);
}
