import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

class ElectrumServerDto {
  final String url;
  final ElectrumServerNetwork network;
  final int priority;
  final bool isCustom;

  ElectrumServerDto({
    required this.url,
    required this.network,
    required this.priority,
    required this.isCustom,
  });

  factory ElectrumServerDto.fromDomain(ElectrumServer domain) {
    return ElectrumServerDto(
      url: domain.url,
      network: domain.network,
      priority: domain.priority,
      isCustom: domain.isCustom,
    );
  }

  ElectrumServer toDomain({String? id}) {
    return ElectrumServer(
      url: url,
      network: network,
      priority: priority,
      isCustom: isCustom,
    );
  }
}
