import 'package:bb_mobile/core/electrum/application/dtos/electrum_server_dto.dart';

class SetCustomServersPriorityRequest {
  final List<ElectrumServerDto> servers;

  SetCustomServersPriorityRequest({required this.servers});
}
