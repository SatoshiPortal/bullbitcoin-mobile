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

  ElectrumSettings({
    required int stopGap,
    required int timeout,
    required int retry,
    required bool validateDomain,
    required ElectrumServerNetwork network,
    String? socks5,
  }) : _stopGap = stopGap,
       _timeout = timeout,
       _retry = retry,
       _validateDomain = validateDomain,
       _network = network,
       _socks5 = socks5;

  int get stopGap => _stopGap;
  int get timeout => _timeout;
  int get retry => _retry;
  bool get validateDomain => _validateDomain;
  ElectrumServerNetwork get network => _network;
  String? get socks5 => _socks5;

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
  }) {
    if (newStopGap != null && newStopGap < 0) {
      throw InvalidStopGapException(newStopGap);
    }
    if (newTimeout != null && newTimeout <= 0) {
      throw InvalidTimeoutException(newTimeout);
    }
    if (newRetry != null && newRetry < 0) {
      throw InvalidRetryException(newRetry);
    }
    // TODO: Add validation for socks5 format or are there too many valid formats?

    _stopGap = newStopGap ?? _stopGap;
    _timeout = newTimeout ?? _timeout;
    _retry = newRetry ?? _retry;
    _validateDomain = newValidateDomain ?? _validateDomain;
    _socks5 = newSocks5Supplier != null ? newSocks5Supplier() : _socks5;
  }
}
