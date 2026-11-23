import 'package:bull_tor/tor.dart';

typedef TorPreferences = ({
  bool useTorProxy,
  int torProxyPort,
  TorTransportMode torTransportMode,
  TorTransport? lastSuccessfulTorTransport,
});
