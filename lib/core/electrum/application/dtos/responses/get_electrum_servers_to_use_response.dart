import 'package:bb_mobile/core/electrum/application/dtos/electrum_server_dto.dart';
import 'package:bb_mobile/core/electrum/application/dtos/electrum_settings_dto.dart';

class GetElectrumServersToUseResponse {
  final List<ElectrumServerDto> servers;
  final ElectrumSettingsDto settings;

  GetElectrumServersToUseResponse({
    required this.servers,
    required this.settings,
  });
}
