import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bull_tor/tor.dart';

abstract class ServerStatusPort {
  Future<ElectrumServerStatus> checkSocket({
    required String url,
    int? timeout,
    TorProxyEndpoint? proxyEndpoint,
  });

  /// Verifies the server actually serves real chain data by fetching a known
  /// historical transaction via `blockchain.transaction.get`. A server that
  /// only responds to `server.version` can still be desynced, pruned, or
  /// otherwise broken — fetching a real tx proves it can answer wallet
  /// queries. Falls back to `server.version` on testnets (no stable txid).
  ///
  /// [validateDomain] must mirror the user's electrum setting of the same
  /// name — the flag the BDK/LWK sync obeys. When true, the certificate
  /// chain, expiry and hostname must all check out; when false, every check
  /// is skipped, so an active MITM becomes indistinguishable from the user's
  /// own node and the user vouches for the endpoint.
  ///
  /// Probing with anything else makes this check lie: a laxer probe reports
  /// a server online that the sync will then refuse, and a stricter one hides
  /// a server that would have worked.
  Future<ElectrumServerStatus> checkElectrum({
    required String url,
    required ElectrumServerNetwork network,
    required bool validateDomain,
    int? timeout,
    TorProxyEndpoint? proxyEndpoint,
  });
}
