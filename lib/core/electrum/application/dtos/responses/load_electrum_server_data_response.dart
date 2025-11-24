import 'package:bb_mobile/core/electrum/application/dtos/electrum_server_dto.dart';
import 'package:bb_mobile/core/electrum/application/dtos/electrum_settings_dto.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';

class LoadElectrumServerDataResponse {
  final List<ElectrumServerDto> servers;
  final Map<String, ElectrumServerStatus> serverStatuses;
  final ElectrumSettingsDto settings;
  final bool useTorProxy;
  final int torProxyPort;

  LoadElectrumServerDataResponse({
    required this.servers,
    required this.serverStatuses,
    required this.settings,
    required this.useTorProxy,
    required this.torProxyPort,
  });
}
