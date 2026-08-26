import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bull_tor/tor.dart';

abstract class ServerStatusPort {
  Future<ElectrumServerStatus> checkSocket({
    required String url,
    int? timeout,
    TorProxyEndpoint? proxyEndpoint,
  });

  /// Verifies the server through the same protocol client used by the wallet.
  /// Bitcoin uses BDK for a header subscription and, on mainnet, a known
  /// historical transaction. Liquid performs the equivalent JSON-RPC probe.
  /// Testnets stop after the protocol/header handshake because they have no
  /// stable probe transaction.
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
    int? retry,
    TorProxyEndpoint? proxyEndpoint,
  });
}
