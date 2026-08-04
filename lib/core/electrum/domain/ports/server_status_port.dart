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
  ///
  /// [skipCertValidation] must be true only for user-configured custom
  /// servers (personal nodes commonly use self-signed certs). It disables
  /// ALL certificate checks — chain, expiry, hostname — so an active MITM is
  /// indistinguishable from the user's node; the user vouches for the
  /// endpoint. Default servers must pass strict CA validation — accepting
  /// any certificate there would let a network attacker MITM the probe and
  /// make a malicious server look healthy.
  Future<ElectrumServerStatus> checkElectrum({
    required String url,
    required ElectrumServerNetwork network,
    required bool skipCertValidation,
    int? timeout,
  });
}
