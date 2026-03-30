import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';

abstract class ServerStatusPort {
  Future<ElectrumServerStatus> checkServerStatus({
    required String url,
    int? timeout,
    bool useTorProxy = false,
    int torProxyPort = 9050,
  });

  /// Verifies the server speaks the Electrum protocol by sending a
  /// `server.version` request. Works on all implementations (ElectrumX,
  /// Fulcrum, electrs). Returns [ElectrumServerStatus.online] if the server
  /// responds with a valid result, [ElectrumServerStatus.offline] otherwise.
  Future<ElectrumServerStatus> checkProtocol({
    required String url,
    int? timeout,
  });
}
