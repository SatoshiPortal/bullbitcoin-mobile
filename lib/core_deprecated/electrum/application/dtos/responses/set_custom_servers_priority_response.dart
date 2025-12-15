import 'package:bb_mobile/core_deprecated/electrum/application/dtos/electrum_server_dto.dart';

class SetCustomServersPriorityResponse {
  final List<ElectrumServerDto> servers;

  SetCustomServersPriorityResponse({required this.servers});
}
