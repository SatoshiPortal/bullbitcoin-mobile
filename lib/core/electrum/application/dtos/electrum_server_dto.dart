import 'package:bb_mobile/features/electrum_settings/domain/electrum_server.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_server_network.dart';

class ElectrumServerDto {
  final String url;
  final ElectrumServerNetwork network;
  final int priority;
  final bool isCustom;
  final bool enableSsl;

  ElectrumServerDto({
    required this.url,
    required this.network,
    required this.priority,
    required this.isCustom,
    this.enableSsl = true,
  });

  factory ElectrumServerDto.fromDomain(ElectrumServer domain) {
    return ElectrumServerDto(
      url: domain.url,
      network: domain.network,
      priority: domain.priority,
      isCustom: domain.isCustom,
    );
  }
}
