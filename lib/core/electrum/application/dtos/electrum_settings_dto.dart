import 'package:bb_mobile/core/electrum/domain/entities/electrum_settings.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

class ElectrumSettingsDto {
  final int stopGap;
  final int timeout;
  final int retry;
  final bool validateDomain;
  final ElectrumServerNetwork network;
  final String? socks5;

  ElectrumSettingsDto({
    required this.stopGap,
    required this.timeout,
    required this.retry,
    required this.validateDomain,
    required this.network,
    this.socks5,
  });

  factory ElectrumSettingsDto.fromDomain(ElectrumSettings domain) {
    return ElectrumSettingsDto(
      stopGap: domain.stopGap,
      timeout: domain.timeout,
      retry: domain.retry,
      validateDomain: domain.validateDomain,
      network: domain.network,
      socks5: domain.socks5,
    );
  }
}
