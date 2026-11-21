import 'package:electrum/src/application/dtos/electrum_server_dto.dart';

class SetCustomServersPriorityResponse {
  final List<ElectrumServerDto> servers;

  SetCustomServersPriorityResponse({required this.servers});
}
