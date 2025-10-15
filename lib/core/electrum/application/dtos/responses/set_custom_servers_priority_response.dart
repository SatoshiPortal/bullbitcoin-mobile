import 'package:bb_mobile/core/electrum/application/dtos/electrum_server_dto.dart';

class SetCustomServersPriorityResponse {
  final List<ElectrumServerDto> servers;

  SetCustomServersPriorityResponse({required this.servers});
}
