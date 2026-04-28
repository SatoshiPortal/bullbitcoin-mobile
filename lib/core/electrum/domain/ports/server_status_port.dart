import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';

abstract class ServerStatusPort {
  Future<ElectrumServerStatus> checkSocket({
    required String url,
    int? timeout,
    bool useTorProxy = false,
    int torProxyPort = 9050,
  });

  /// Verifies the server actually serves real chain data by fetching a known
  /// historical transaction via `blockchain.transaction.get`. A server that
  /// only responds to `server.version` can still be desynced, pruned, or
  /// otherwise broken — fetching a real tx proves it can answer wallet
  /// queries. Falls back to `server.version` on testnets (no stable txid).
  Future<ElectrumServerStatus> checkElectrum({
    required String url,
    required ElectrumServerNetwork network,
    int? timeout,
  });
}
