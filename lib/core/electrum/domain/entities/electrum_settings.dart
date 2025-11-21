import 'package:bb_mobile/core/electrum/domain/errors/electrum_settings_exception.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

class ElectrumSettings {
  int _stopGap;
  int _timeout;
  int _retry;
  bool _validateDomain;
  // It should not be possible to change the environment of existing settings
  //  as they are tied to just one environment, so it's final
  final ElectrumServerNetwork _network;
  String? _socks5;
  bool _useTorProxy;
  int _torProxyPort;

  static const int maxStopGap = 3000;
  static const int maxTimeout = 300; // 5 minutes
  static const int defaultTorProxyPort = 9050; // Orbot default port

  ElectrumSettings({
    required int stopGap,
    required int timeout,
    required int retry,
    required bool validateDomain,
    required ElectrumServerNetwork network,
    String? socks5,
    bool useTorProxy = false,
    int torProxyPort = defaultTorProxyPort,
  }) : _stopGap = stopGap,
       _timeout = timeout,
       _retry = retry,
       _validateDomain = validateDomain,
       _network = network,
       _socks5 = socks5,
       _useTorProxy = useTorProxy,
       _torProxyPort = torProxyPort;

  int get stopGap => _stopGap;
  int get timeout => _timeout;
  int get retry => _retry;
  bool get validateDomain => _validateDomain;
  ElectrumServerNetwork get network => _network;
  String? get socks5 => _socks5;
  bool get useTorProxy => _useTorProxy;
  int get torProxyPort => _torProxyPort;

  void update({
    int? newStopGap,
    int? newTimeout,
    int? newRetry,
    bool? newValidateDomain,
    // Usage of a supplier function to handle nullable updates for socks5:
    // `newSocks5Supplier: null` or not specifying socks5 to keep current value
    // `newSocks5Supplier: () => 'new_value'` to set a new value
    // `newSocks5Supplier: () => null` to clear the value and make socks5 null
    String? Function()? newSocks5Supplier,
    bool? newUseTorProxy,
    int? newTorProxyPort,
  }) {
    if (newStopGap != null) {
      _ensureValidStopGap(newStopGap);
    }
    if (newTimeout != null) {
      _ensureValidTimeout(newTimeout);
    }
    if (newRetry != null) {
      _ensureValidRetry(newRetry);
    }
    if (newTorProxyPort != null) {
      _ensureValidTorProxyPort(newTorProxyPort);
    }
    // TODO: Add validation for socks5 format or are there too many valid formats?

    _stopGap = newStopGap ?? _stopGap;
    _timeout = newTimeout ?? _timeout;
    _retry = newRetry ?? _retry;
    _validateDomain = newValidateDomain ?? _validateDomain;
    _socks5 = newSocks5Supplier != null ? newSocks5Supplier() : _socks5;
    _useTorProxy = newUseTorProxy ?? _useTorProxy;
    _torProxyPort = newTorProxyPort ?? _torProxyPort;
  }

  void _ensureValidStopGap(int stopGap) {
    if (stopGap < 0 || stopGap > maxStopGap) {
      throw InvalidStopGapException(stopGap);
    }
  }

  void _ensureValidTimeout(int timeout) {
    if (timeout <= 0 || timeout > maxTimeout) {
      throw InvalidTimeoutException(timeout);
    }
  }

  void _ensureValidRetry(int retry) {
    if (retry < 0) {
      throw InvalidRetryException(retry);
    }
  }

  void _ensureValidTorProxyPort(int port) {
    if (port < 1 || port > 65535) {
      throw InvalidTorProxyPortException(port);
    }
  }
}
