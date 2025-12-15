import 'package:bb_mobile/core_deprecated/electrum/domain/value_objects/electrum_server_status.dart';

abstract class ServerStatusPort {
  Future<ElectrumServerStatus> checkServerStatus({
    required String url,
    int? timeout,
    bool useTorProxy = false,
    int torProxyPort = 9050,
  });
}
