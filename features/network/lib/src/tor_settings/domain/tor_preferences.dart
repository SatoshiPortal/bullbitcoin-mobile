import 'package:bull_tor/tor.dart';

typedef TorPreferences = ({
  bool useTorProxy,
  int torProxyPort,
  TorTransportMode torTransportMode,
  TorTransport? lastSuccessfulTorTransport,
});

typedef ReadTorPreferences = Future<TorPreferences> Function();
typedef SaveTorProxy = Future<bool> Function({
  required bool enabled,
  required int port,
});
