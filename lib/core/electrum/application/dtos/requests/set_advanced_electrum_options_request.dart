import 'package:bb_mobile/core/electrum/application/dtos/electrum_settings_dto.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

class SetAdvancedElectrumOptionsRequest {
  final ElectrumSettingsDto options;

  SetAdvancedElectrumOptionsRequest({required this.options});

  int get stopGap => options.stopGap;
  int get timeout => options.timeout;
  int get retry => options.retry;
  bool get validateDomain => options.validateDomain;
  String? get socks5 => options.socks5;
  ElectrumServerNetwork get network => options.network;
}
