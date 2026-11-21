import 'package:electrum/src/application/dtos/electrum_server_dto.dart';
import 'package:electrum/src/application/dtos/electrum_settings_dto.dart';
import 'package:electrum/src/domain/value_objects/electrum_server_status.dart';

class LoadElectrumServerDataResponse {
  final List<ElectrumServerDto> servers;
  final Map<String, ElectrumServerStatus> serverStatuses;
  final ElectrumSettingsDto settings;

  LoadElectrumServerDataResponse({
    required this.servers,
    required this.serverStatuses,
    required this.settings,
  });
}
