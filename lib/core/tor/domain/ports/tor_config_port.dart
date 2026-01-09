import 'package:bb_mobile/core/tor/domain/value_objects/tor_proxy_config.dart';

abstract class TorConfigPort {
  /// Get the Tor proxy configuration
  /// Returns null if internal Tor should be used
  /// Returns TorProxyConfig if external Tor proxy is configured
  Future<TorProxyConfig?> getExternalTorConfig();
}
