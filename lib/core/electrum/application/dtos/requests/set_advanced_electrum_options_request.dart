import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

class SetAdvancedElectrumOptionsRequest {
  final int stopGap;
  final int timeout;
  final int retry;
  final bool validateDomain;
  final String socks5;
  final ElectrumServerNetwork network;

  SetAdvancedElectrumOptionsRequest({
    required this.stopGap,
    required this.timeout,
    required this.retry,
    required this.validateDomain,
    required this.socks5,
    required this.network,
  });
}
